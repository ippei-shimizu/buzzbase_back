module Api
  module V2
    class MediaAttachmentsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_media_attachment

      # アップロード完了通知（file_size_bytesを含む）とメモ更新は同じPATCHで受け、
      # パラメータの形で意図を判別する。前者はstatus: pending時のみの一度きりの遷移。
      def update
        if params[:media_attachment]&.key?(:file_size_bytes)
          complete_upload
        else
          update_memo
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

      def complete_upload
        return render json: { errors: ['既に完了処理済みです'] }, status: :unprocessable_entity unless @media_attachment.status == 'pending'

        @media_attachment.assign_attributes(completion_params)

        actual_size = ::MediaAttachments::ObjectSizeFetcher.new(r2_key: @media_attachment.r2_key).call
        if actual_size.nil?
          @media_attachment.update!(status: 'failed')
          return render json: { errors: ['アップロードが確認できませんでした'] }, status: :unprocessable_entity
        end
        # file_size_bytesはクライアントの自己申告値のため、R2上の実サイズで上書きしてから検証する。
        @media_attachment.file_size_bytes = actual_size

        return unless overwrite_video_metadata!

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

      # duration_seconds / width / height もfile_size_bytesと同じくクライアントの自己申告値なので、
      # R2上の実ファイルから読み直した値で上書きしてから無料枠判定にかける。
      # 解析できない動画は上限を検証できないため、素通しさせずアップロードを失敗させる。
      # @return [Boolean] 処理を継続してよいか（falseのときは既にrender済み）
      def overwrite_video_metadata!
        return true unless @media_attachment.video?

        metadata = ::MediaAttachments::VideoMetadataFetcher.new(r2_key: @media_attachment.r2_key).call
        if metadata.nil?
          @media_attachment.update!(status: 'failed')
          render json: { errors: ['動画の形式を確認できませんでした'] }, status: :unprocessable_entity
          return false
        end

        @media_attachment.assign_attributes(metadata.to_h)
        true
      end

      def update_memo
        if @media_attachment.update(memo_params)
          render json: @media_attachment, serializer: ::V2::MediaAttachmentSerializer, status: :ok
        else
          render json: { errors: @media_attachment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def completion_params
        params.require(:media_attachment).permit(:duration_seconds, :width, :height, :file_size_bytes, :memo)
      end

      def memo_params
        params.require(:media_attachment).permit(:memo)
      end
    end
  end
end
