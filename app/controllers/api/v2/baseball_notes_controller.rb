module Api
  module V2
    # 野球ノート（v2）。試合 / 練習への紐付けに対応（モデルA）。
    # メディア（画像・動画）は別 PR。本コントローラはテキスト＋紐付けのみ。
    class BaseballNotesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_note, only: %i[show update destroy]

      FILTERABLE_COLUMNS = %i[date game_result_id practice_log_id practice_session_id improvement_theme_id].freeze

      def index
        notes = current_api_v1_user.baseball_notes.order(date: :desc, created_at: :desc)
        FILTERABLE_COLUMNS.each do |column|
          notes = notes.where(column => params[column]) if params[column].present?
        end
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
        params.require(:baseball_note).permit(:title, :date, :memo, :game_result_id, :practice_log_id,
                                              :practice_session_id, :improvement_theme_id)
      end

      # 紐付け先カラム => { association:, error: } の対応。所有検証（IDOR 防止）に使う。
      LINK_OWNERSHIPS = {
        game_result_id: { association: :game_results, error: '不正な試合の指定です' },
        practice_log_id: { association: :practice_logs, error: '不正な練習の指定です' },
        practice_session_id: { association: :practice_sessions, error: '不正な練習記録の指定です' },
        improvement_theme_id: { association: :improvement_themes, error: '不正な課題の指定です' }
      }.freeze

      # 他ユーザーの試合 / 練習 / 課題に紐付けられないよう所有を検証する（IDOR 防止）。
      def valid_links?(note)
        LINK_OWNERSHIPS.each do |column, config|
          id = note.public_send(column)
          next if id.blank? || current_api_v1_user.public_send(config[:association]).exists?(id)

          render json: { error: config[:error] }, status: :forbidden
          return false
        end
        true
      end
    end
  end
end
