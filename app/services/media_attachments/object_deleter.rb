module MediaAttachments
  # R2上のオブジェクト（本体・サムネイル）をまとめて削除する。
  class ObjectDeleter
    def initialize(keys:)
      @keys = keys.compact
    end

    def call
      return if @keys.empty?

      PresignedUrlService.client.delete_objects(
        bucket: ENV.fetch('R2_BUCKET_NAME'),
        delete: { objects: @keys.map { |key| { key: } } }
      )
    end
  end
end
