module MediaAttachments
  # 非公開のR2バケットから閲覧するための、有効期限付き署名GET URLを発行する。
  module SignedGetUrlBuilder
    SIGNING_WINDOW = 1.hour
    EXPIRES_IN = (SIGNING_WINDOW * 2).to_i

    module_function

    # @param key [String, nil] R2オブジェクトキー
    # @return [String, nil] 署名済みGET URL。keyが空ならnil
    def for(key)
      return nil if key.blank?

      Aws::S3::Presigner.new(client: PresignedUrlService.client).presigned_url(
        :get_object,
        bucket: ENV.fetch('R2_BUCKET_NAME'),
        key:,
        expires_in: EXPIRES_IN,
        time: signing_time
      )
    end

    # 署名時刻を窓の先頭に揃えて同じ窓内ではURLを不変にし、クライアントの画像キャッシュを効かせる。
    # 有効期限を窓の2倍にしているので、発行時点から最低でも窓1つ分（1時間）は再生できる。
    def signing_time
      Time.zone.at((Time.current.to_i / SIGNING_WINDOW.to_i) * SIGNING_WINDOW.to_i)
    end
  end
end
