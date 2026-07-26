module MediaAttachments
  # クライアント自己申告のfile_size_bytesは改ざん可能なため、完了処理時にR2上の実サイズで
  # 上書きして検証する。呼び出し時点でPUTは完了している前提のため、存在しない場合は
  # アップロード自体が完了していないとみなす。
  class ObjectSizeFetcher
    def initialize(r2_key:)
      @r2_key = r2_key
    end

    # @return [Integer, nil] オブジェクトがR2上に存在しない場合はnil
    def call
      PresignedUrlService.client.head_object(
        bucket: ENV.fetch('R2_BUCKET_NAME'),
        key: @r2_key
      ).content_length
    rescue Aws::S3::Errors::NotFound
      nil
    end
  end
end
