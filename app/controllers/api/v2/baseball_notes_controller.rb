module Api
  module V2
    # 野球ノート（v2）。試合 / 練習への紐付けに対応（モデルA）。
    # メディア（画像・動画）は別 PR。本コントローラはテキスト＋紐付けのみ。
    class BaseballNotesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_note, only: %i[show update destroy]

      def index
        notes = current_api_v1_user.baseball_notes.order(date: :desc, created_at: :desc)
        notes = notes.where(date: params[:date]) if params[:date].present?
        notes = notes.where(game_result_id: params[:game_result_id]) if params[:game_result_id].present?
        notes = notes.where(practice_log_id: params[:practice_log_id]) if params[:practice_log_id].present?
        notes = notes.where(practice_session_id: params[:practice_session_id]) if params[:practice_session_id].present?
        render json: notes, each_serializer: ::V2::BaseballNoteSerializer, status: :ok
      end

      def show
        render json: @note, serializer: ::V2::BaseballNoteSerializer, status: :ok
      end

      def create
        note = current_api_v1_user.baseball_notes.build(note_params)
        return unless valid_links?(note)

        if note.save
          render json: note, serializer: ::V2::BaseballNoteSerializer, status: :created
        else
          render json: { errors: note.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        @note.assign_attributes(note_params)
        return unless valid_links?(@note)

        if @note.save
          render json: @note, serializer: ::V2::BaseballNoteSerializer, status: :ok
        else
          render json: { errors: @note.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @note.destroy
        render json: { message: '削除しました' }, status: :ok
      end

      private

      def load_note
        @note = current_api_v1_user.baseball_notes.find(params[:id])
      end

      def note_params
        params.require(:baseball_note).permit(:title, :date, :memo, :game_result_id, :practice_log_id, :practice_session_id)
      end

      # 他ユーザーの試合 / 練習に紐付けられないよう所有を検証する（IDOR 防止）。
      def valid_links?(note)
        if note.game_result_id && !current_api_v1_user.game_results.exists?(note.game_result_id)
          render json: { error: '不正な試合の指定です' }, status: :forbidden
          return false
        end
        if note.practice_log_id && !current_api_v1_user.practice_logs.exists?(note.practice_log_id)
          render json: { error: '不正な練習の指定です' }, status: :forbidden
          return false
        end
        if note.practice_session_id && !current_api_v1_user.practice_sessions.exists?(note.practice_session_id)
          render json: { error: '不正な練習記録の指定です' }, status: :forbidden
          return false
        end
        true
      end
    end
  end
end
