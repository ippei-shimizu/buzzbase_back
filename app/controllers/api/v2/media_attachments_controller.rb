module Api
  module V2
    class MediaAttachmentsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_media_attachment

      def update
        return render json: { errors: ['既に完了処理済みです'] }, status: :unprocessable_entity unless @media_attachment.status == 'pending'

        @media_attachment.assign_attributes(completion_params)
        unless ::MediaAttachments::LimitValidator.new(user: current_api_v1_user, attachment: @media_attachment).valid?
          @media_attachment.update!(status: 'failed')
          return render json: { errors: ['アップロード可能な上限を超えています'] }, status: :unprocessable_entity
        end

        @media_attachment.status = 'ready'
        if @media_attachment.save
          render json: @media_attachment, serializer: ::V2::MediaAttachmentSerializer, status: :ok
        else
          render json: { errors: @media_attachment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @media_attachment.destroy
        render json: { message: '削除しました' }, status: :ok
      end

      private

      def load_media_attachment
        @media_attachment = current_api_v1_user.media_attachments.find(params[:id])
      end

      def completion_params
        params.require(:media_attachment).permit(:duration_seconds, :width, :height, :file_size_bytes)
      end
    end
  end
end
