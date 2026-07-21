module V2
  class MediaAttachmentSerializer < ActiveModel::Serializer
    attributes :id, :media_type, :status, :file_size_bytes, :duration_seconds,
               :width, :height, :position, :memo, :playback_url, :thumbnail_url, :created_at

    def playback_url
      ::MediaAttachments::PublicUrlBuilder.for(object.r2_key)
    end

    def thumbnail_url
      ::MediaAttachments::PublicUrlBuilder.for(object.thumbnail_r2_key)
    end
  end
end
