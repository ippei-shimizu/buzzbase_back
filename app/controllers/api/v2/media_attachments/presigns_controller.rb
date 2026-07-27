module Api
  module V2
    module MediaAttachments
      # メディア添付の署名アップロードURLを発行する。本体は常にクライアントからR2へ直接PUTする。
      class PresignsController < Api::V2::ApplicationController
        before_action :authenticate_api_v1_user!

        # media_typeごとに許可するcontent_typeを分けることで、例えば
        # media_type: 'image' に content_type: 'video/mp4' を組み合わせて
        # LimitValidatorの動画チェック（長さ・解像度）を回避されるのを防ぐ。
        CONTENT_TYPE_EXTENSIONS_BY_MEDIA_TYPE = {
          'image' => {
            'image/jpeg' => 'jpg',
            'image/png' => 'png',
            'image/heic' => 'heic'
          }.freeze,
          'video' => {
            'video/mp4' => 'mp4',
            'video/quicktime' => 'mov'
          }.freeze
        }.freeze

        def create
          note = current_api_v1_user.baseball_notes.find(presign_params[:baseball_note_id])

          return render json: { error: '今月のアップロード上限に達しています' }, status: :forbidden unless current_api_v1_user.can_upload_media_this_month?

          extension = extension_for(presign_params[:media_type], presign_params[:content_type])
          return render json: { errors: ['対応していないファイル形式です'] }, status: :unprocessable_entity unless extension

          attachment = build_attachment(note, extension)
          if attachment.save
            render json: presign_response(attachment), status: :created
          else
            render json: { errors: attachment.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def presign_params
          params.require(:media_attachment).permit(:baseball_note_id, :media_type, :content_type)
        end

        def extension_for(media_type, content_type)
          CONTENT_TYPE_EXTENSIONS_BY_MEDIA_TYPE[media_type]&.[](content_type)
        end

        def build_attachment(note, extension)
          key = "#{note.user_id}/#{note.id}/#{SecureRandom.uuid}.#{extension}"
          is_video = presign_params[:media_type] == 'video'
          current_api_v1_user.media_attachments.new(
            baseball_note: note,
            media_type: presign_params[:media_type],
            r2_key: key,
            thumbnail_r2_key: is_video ? key.sub(/\.\w+\z/, '_thumb.jpg') : nil,
            status: 'pending'
          )
        end

        def presign_response(attachment)
          {
            id: attachment.id,
            media_type: attachment.media_type,
            status: attachment.status,
            upload_url: signed_url(attachment.r2_key, presign_params[:content_type]),
            thumbnail_upload_url: attachment.thumbnail_r2_key && signed_url(attachment.thumbnail_r2_key, 'image/jpeg')
          }
        end

        def signed_url(key, content_type)
          ::MediaAttachments::PresignedUrlService.new(r2_key: key, content_type:).call
        end
      end
    end
  end
end
