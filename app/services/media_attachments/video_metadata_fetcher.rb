module MediaAttachments
  # R2 上の実オブジェクトから動画の再生時間・解像度を読み取る。
  #
  # クライアント申告の duration_seconds / width / height は file_size_bytes と同様に改ざん可能で、
  # そのまま無料枠判定に使うと長時間・高解像度の動画を「30秒 / 480p」と偽って保存できてしまう。
  # ffprobe を導入するとイメージへの ffmpeg 同梱とファイル全体のダウンロードが必要になるため、
  # MP4 / MOV（ISO BMFF）のヘッダだけを Range GET で取得して解析する。
  #
  # moov ボックスの位置は端末・エンコーダによって先頭にも末尾にも来るため、トップレベルの
  # ボックスヘッダ（8〜16バイト）だけを辿って moov を探し、見つけたボックスの範囲のみ取得する。
  # mdat 本体は一切ダウンロードしない。
  class VideoMetadataFetcher
    Metadata = Struct.new(:duration_seconds, :width, :height, keyword_init: true)

    # 壊れた・想定外の構造のファイルで無限に Range GET を繰り返さないための保険。
    MAX_TOP_LEVEL_BOXES = 32
    # moov は長尺・多トラックでも通常は数百KB。極端に大きい値は解析対象外にする。
    MAX_MOOV_BYTES = 16 * 1024 * 1024
    # duration が未定義のとき全ビット 1 が入る仕様のため、非現実的な長さは解析失敗として扱う。
    MAX_DURATION_SECONDS = 24 * 60 * 60
    BOX_HEADER_BYTES = 16

    def initialize(r2_key:)
      @r2_key = r2_key
    end

    # @return [Metadata, nil] 解析できなかった場合は nil
    def call
      moov = fetch_moov
      return nil if moov.nil?

      duration = parse_duration(moov)
      dimensions = parse_dimensions(moov)
      return nil if duration.nil? || dimensions.nil?

      Metadata.new(duration_seconds: duration, width: dimensions.first, height: dimensions.last)
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::InvalidRange
      nil
    rescue Aws::S3::Errors::ServiceError => e
      Sentry.capture_exception(e, tags: { source: 'video_metadata_fetcher' }, extra: { r2_key: @r2_key })
      nil
    end

    private

    # トップレベルのボックスを順に辿り、moov ボックスの中身を返す。
    def fetch_moov
      offset = 0
      MAX_TOP_LEVEL_BOXES.times do
        header = read_range(offset, offset + BOX_HEADER_BYTES - 1)
        size, header_size = box_size(header)
        return nil if size.nil?

        return read_moov(offset + header_size, size - header_size) if header.byteslice(4, 4) == 'moov'

        offset += size
      end
      nil
    end

    # size == 1 は 64bit largesize、size == 0 は「以降ファイル終端まで」を意味する。
    # 後者は mdat が最後に置かれたケースで、その先にボックスは無いので解析を打ち切る。
    # @return [Array(Integer, Integer), Array(nil, nil)] [ボックス全体のバイト数, ヘッダのバイト数]
    def box_size(header)
      return [nil, nil] if header.nil? || header.bytesize < 8

      size = header.unpack1('N')
      return [size, 8] if size > 8
      return [nil, nil] unless size == 1 && header.bytesize >= BOX_HEADER_BYTES

      large_size = header.byteslice(8, 8).unpack1('Q>')
      large_size > BOX_HEADER_BYTES ? [large_size, BOX_HEADER_BYTES] : [nil, nil]
    end

    def read_moov(offset, length)
      return nil if length <= 0 || length > MAX_MOOV_BYTES

      body = read_range(offset, offset + length - 1)
      body.bytesize == length ? body : nil
    end

    def read_range(from, to)
      PresignedUrlService.client.get_object(
        bucket: ENV.fetch('R2_BUCKET_NAME'),
        key: @r2_key,
        range: "bytes=#{from}-#{to}"
      ).body.read.b
    end

    # mvhd の timescale / duration から秒数を求める。
    # 端数は切り上げる（30.4秒の動画を 30秒として無料枠に通さない）。
    def parse_duration(moov)
      mvhd = find_box(moov, 'mvhd')
      return nil if mvhd.nil? || mvhd.bytesize < 32

      timescale, duration = mvhd.getbyte(0) == 1 ? mvhd.byteslice(20, 12).unpack('NQ>') : mvhd.byteslice(12, 8).unpack('N2')
      return nil if timescale.nil? || timescale.zero? || duration.nil?

      seconds = (duration.to_f / timescale).ceil
      seconds <= MAX_DURATION_SECONDS ? seconds : nil
    end

    # 映像トラックの tkhd から表示サイズを求める。音声トラックは 0x0 なので自然に除外される。
    # 複数の映像トラックがある場合は最大の解像度を採用する（上限判定を甘くしないため）。
    def parse_dimensions(moov)
      dimensions = each_box(moov).select { |type, _| type == 'trak' }
                                 .filter_map { |_, trak| track_dimensions(trak) }
      return nil if dimensions.empty?

      [dimensions.map(&:first).max, dimensions.map(&:last).max]
    end

    def track_dimensions(trak)
      tkhd = find_box(trak, 'tkhd')
      return nil if tkhd.nil?

      # version + flags(4) + creation/modification/track_ID/reserved/duration + reserved(8) + layer〜volume(8)
      matrix_offset = tkhd.getbyte(0) == 1 ? 52 : 40
      width, height = display_size(tkhd.byteslice(matrix_offset + 36, 8))
      return nil if width.nil?

      rotated?(tkhd.byteslice(matrix_offset, 36)) ? [height, width] : [width, height]
    end

    # tkhd の width / height は 16.16 固定小数点。0x0 は映像を持たないトラック（音声など）。
    def display_size(bytes)
      width, height = bytes&.unpack('N2')
      return nil if width.nil? || height.nil?

      width /= 65_536
      height /= 65_536
      [width, height] unless width.zero? || height.zero?
    end

    # 表示マトリクスが 90 / 270 度回転（a=d=0, b・c が非ゼロ）なら、tkhd の width / height は
    # 回転前の値なので入れ替える。縦持ち撮影の動画でクライアント申告値と揃える。
    def rotated?(matrix)
      return false if matrix.nil? || matrix.bytesize < 36

      a, b, _u, c, d = matrix.unpack('l>5')
      a.zero? && d.zero? && !b.zero? && !c.zero?
    end

    def find_box(container, target_type)
      each_box(container).find { |type, _| type == target_type }&.last
    end

    # コンテナ直下のボックスを [type, payload] として列挙する。
    def each_box(container)
      Enumerator.new do |yielder|
        offset = 0
        while offset + 8 <= container.bytesize
          size, header_size = box_size(container.byteslice(offset, BOX_HEADER_BYTES))
          break if size.nil? || offset + size > container.bytesize

          yielder << [container.byteslice(offset + 4, 4), container.byteslice(offset + header_size, size - header_size)]
          offset += size
        end
      end
    end
  end
end
