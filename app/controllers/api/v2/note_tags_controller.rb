module Api
  module V2
    # 野球ノートのタグ。運営プリセット＋ユーザー自作（ハイブリッド）。
    class NoteTagsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        tags = ::NoteTag.available_for(current_api_v1_user).ordered
        render json: tags, each_serializer: ::V2::NoteTagSerializer, status: :ok
      end

      def create
        tag = current_api_v1_user.note_tags.new(name: tag_params[:name])
        if tag.save
          render json: tag, serializer: ::V2::NoteTagSerializer, status: :created
        else
          render json: { errors: tag.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def tag_params
        params.require(:note_tag).permit(:name)
      end
    end
  end
end
