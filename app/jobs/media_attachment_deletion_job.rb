class MediaAttachmentDeletionJob < ApplicationJob
  queue_as :default

  def perform(r2_key, thumbnail_r2_key = nil)
    MediaAttachments::ObjectDeleter.new(keys: [r2_key, thumbnail_r2_key]).call
  end
end
