module MediaAttachments
  # Cloudflare R2（S3互換）への署名PUT URLを発行する。
  # 本体アップロードは常にクライアントからR2へ直接行い、サーバーはURL発行のみを担う。
  class PresignedUrlService
    PUT_EXPIRES_IN = 10.minutes.to_i

    # @param r2_key [String] R2オブジェクトキー
    # @param content_type [String] MIMEタイプ
    def initialize(r2_key:, content_type:)
      @r2_key = r2_key
      @content_type = content_type
    end

    # @return [String] 署名済みPUT URL
    def call
      presigner.presigned_url(
        :put_object,
        bucket: ENV.fetch('R2_BUCKET_NAME'),
        key: @r2_key,
        content_type: @content_type,
        expires_in: PUT_EXPIRES_IN
      )
    end

    class << self
      # R2はバケット名を含むvirtual-hosted style解決に対応しないため path_style を強制する。
      def client
        @client ||= Aws::S3::Client.new(
          endpoint: ENV.fetch('R2_ENDPOINT'),
          region: 'auto',
          access_key_id: ENV.fetch('R2_ACCESS_KEY_ID'),
          secret_access_key: ENV.fetch('R2_SECRET_ACCESS_KEY'),
          force_path_style: true,
          # このクライアントは動画メタデータ検証（Range GET / HEAD、1リクエストで最大34往復）
          # にも使われ、リクエスト経路で同期実行される。SDK 既定（open 15秒 / read 60秒 /
          # リトライ3回）では R2 が詰まったとき1リクエストが数分ブロックし、Puma スレッドと
          # DB コネクションを占有するため短く明示する。Range GET は数KB単位なので read 5秒で十分。
          http_open_timeout: 3,
          http_read_timeout: 5,
          retry_limit: 1
        )
      end
    end

    private

    def presigner
      Aws::S3::Presigner.new(client: self.class.client)
    end
  end
end
