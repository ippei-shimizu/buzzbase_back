module Api
  module V2
    # 野球ノート（v2）。試合 / 練習への紐付けに対応（モデルA）。
    # メディア（画像・動画）は別 PR。本コントローラはテキスト＋紐付けのみ。
    class BaseballNotesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_note, only: %i[show update destroy]

      FILTERABLE_COLUMNS = %i[date game_result_id practice_log_id practice_session_id improvement_theme_id].freeze

      def index
        notes = current_api_v1_user.baseball_notes.includes(:note_tags).order(date: :desc, created_at: :desc)
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
        return unless valid_links?(note) && valid_note_tags?(tag_id_params)

        saved = ActiveRecord::Base.transaction do
          next false unless note.save

          note.note_tag_ids = tag_id_params
          true
        end
        if saved
          render json: note, serializer: ::V2::BaseballNoteSerializer, status: :created
        else
          render json: { errors: note.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        @note.assign_attributes(note_params)
        return unless valid_links?(@note) && valid_note_tags?(tag_id_params)

        saved = ActiveRecord::Base.transaction do
          next false unless @note.save

          @note.note_tag_ids = tag_id_params
          true
        end
        if saved
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
                                              :practice_session_id, :improvement_theme_id, :reflection_template_id,
                                              reflection_answers: %i[question answer])
      end

      # タグは has_many through の即時保存を避けるため mass-assign せず、
      # 所有検証後に別途 note_tag_ids= で反映する。
      # 重複IDのまま渡すと ids_writer が同一レコードを二重 add しようとしうるため uniq する。
      def tag_id_params
        params.require(:baseball_note).fetch(:tag_ids, []).map(&:to_i).uniq
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
        valid_reflection_template?(note)
      end

      # 振り返りテンプレはプリセット or 自作のみ紐付け可（他ユーザーの自作は不可）。
      def valid_reflection_template?(note)
        return true if note.reflection_template_id.blank?
        return true if ReflectionTemplate.available_for(current_api_v1_user).exists?(note.reflection_template_id)

        render json: { error: '不正なテンプレの指定です' }, status: :forbidden
        false
      end

      # タグはプリセット or 自作のみ付与可（他ユーザーの自作は不可）。
      def valid_note_tags?(tag_ids)
        return true if tag_ids.blank?
        return true if ::NoteTag.available_for(current_api_v1_user).where(id: tag_ids).count == tag_ids.uniq.size

        render json: { error: '不正なタグの指定です' }, status: :forbidden
        false
      end
    end
  end
end
