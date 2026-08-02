# VideoMetadataFetcher の検証用に、最小構成の ISO BMFF（MP4）バイト列を組み立てる。
# 実ファイルを fixture に置くと解像度・長さのバリエーションごとにバイナリが増えるため、
# 解析対象のボックス（ftyp / moov(mvhd + trak(tkhd)) / mdat）だけをその場で生成する。
module Mp4Builder
  IDENTITY_MATRIX = [0x0001_0000, 0, 0, 0, 0x0001_0000, 0, 0, 0, 0x4000_0000].freeze
  # 90度回転（縦持ち撮影）。a = d = 0 で b / c が非ゼロ。
  ROTATED_MATRIX = [0, 0x0001_0000, 0, -0x0001_0000, 0, 0, 0, 0, 0x4000_0000].freeze

  # @param duration_seconds [Numeric] mvhd に書き込む再生時間
  # @param width [Integer] tkhd の表示幅（回転時は入れ替え前の値）
  # @param height [Integer] tkhd の表示高さ
  # @param timescale [Integer] mvhd の timescale
  # @param rotated [Boolean] 90度回転の表示マトリクスを書き込むか
  # @param moov_last [Boolean] moov を mdat の後ろに置くか（Android 端末の典型配置）
  # @param audio_track [Boolean] 0x0 サイズの音声トラックを混ぜるか
  # @return [String] ASCII-8BIT のバイト列
  def build_mp4(duration_seconds:, width:, height:, timescale: 600, rotated: false, moov_last: false, audio_track: false)
    traks = []
    traks << trak(width: 0, height: 0, duration_seconds:, timescale:) if audio_track
    traks << trak(width:, height:, duration_seconds:, timescale:, rotated:)

    moov = box('moov', mvhd(duration_seconds:, timescale:) + traks.join)
    mdat = box('mdat', "\x00".b * 512)

    parts = moov_last ? [ftyp, mdat, moov] : [ftyp, moov, mdat]
    parts.join.b
  end

  # 指定バイト列を Range GET で返す R2 クライアントをスタブする。
  # 範囲外の要求は実際の S3 / R2 と同じく InvalidRange で失敗させる。
  def stub_r2_video_object(bytes)
    allow(MediaAttachments::PresignedUrlService.client).to receive(:get_object) do |args|
      from, to = args[:range].delete_prefix('bytes=').split('-').map(&:to_i)
      raise Aws::S3::Errors::InvalidRange.new(nil, 'range not satisfiable') if from >= bytes.bytesize

      instance_double(Aws::S3::Types::GetObjectOutput, body: StringIO.new(bytes.byteslice(from, to - from + 1)))
    end
  end

  private

  def box(type, payload)
    [8 + payload.bytesize].pack('N') + type.b + payload
  end

  def ftyp
    box('ftyp', "isom\x00\x00\x02\x00isomiso2avc1mp41".b)
  end

  def mvhd(duration_seconds:, timescale:)
    payload = [0].pack('N')                                   # version 0 + flags
    payload += [0, 0, timescale, (duration_seconds * timescale).round].pack('N4')
    payload += [0x0001_0000].pack('N')                        # rate
    payload += [0x0100].pack('n')                             # volume
    payload += "\x00".b * 10                                  # reserved
    payload += IDENTITY_MATRIX.pack('l>9')
    payload += "\x00".b * 24                                  # pre_defined
    box('mvhd', payload + [2].pack('N'))                      # next_track_ID
  end

  def trak(width:, height:, duration_seconds:, timescale:, rotated: false)
    payload = [0x0000_0003].pack('N')                         # version 0 + flags(enabled / in movie)
    payload += [0, 0, 1, 0, (duration_seconds * timescale).round].pack('N5')
    payload += "\x00".b * 8                                   # reserved
    payload += [0, 0, 0, 0].pack('n4')                        # layer / alternate_group / volume / reserved
    payload += (rotated ? ROTATED_MATRIX : IDENTITY_MATRIX).pack('l>9')
    box('trak', box('tkhd', payload + [width * 65_536, height * 65_536].pack('N2')))
  end
end

RSpec.configure do |config|
  config.include Mp4Builder
end
