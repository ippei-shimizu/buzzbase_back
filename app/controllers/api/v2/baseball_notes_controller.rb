module Api
  module V2
    # 野球ノート（v2）。試合 / 練習への紐付けに対応（モデルA）。
    # メディア（画像・動画）の作成・完了通知・削除は Api::V2::MediaAttachments 配下の別コントローラで扱う。
    class BaseballNotesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_note, only: %i[show update destroy]

      FILTERABLE_COLUMNS = %i[date practice_log_id practice_session_id].freeze

      def index
        notes = current_api_v1_user.baseball_notes
                                   .includes(:note_tags, :game_results, :improvement_themes, :media_attachments)
                                   .order(date: :desc, created_at: :desc)
        FILTERABLE_COLUMNS.each do |column|
          notes = notes.where(column => params[column]) if params[column].present?
        end
        if params[:game_result_id].present?
          notes = notes.joins(:note_game_links).where(note_game_links: { game_result_id: params[:game_result_id] })
        end
        if params[:improvement_theme_id].present?
          notes = notes.joins(:note_theme_links)
                       .where(note_theme_links: { improvement_theme_id: params[:improvement_theme_id] })
        end
        render json: notes, each_serializer: ::V2::BaseballNoteSerializer, status: :ok
      end

      def show
        render json: @note, serializer: ::V2::BaseballNoteSerializer, status: :ok
      end

      def create
        note = current_api_v1_user.baseball_notes.build(note_params)
        tag_ids = tag_id_params
        game_result_ids = game_result_id_params
        theme_ids = improvement_theme_id_params
        return unless valid_links?(note) && valid_note_tags?(tag_ids) &&
                      valid_game_results?(game_result_ids) && valid_improvement_themes?(theme_ids)

        saved = ActiveRecord::Base.transaction do
          next false unless note.save

          apply_links(note, tag_ids, game_result_ids, theme_ids)
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
        tag_ids = tag_id_params
        game_result_ids = game_result_id_params
        theme_ids = improvement_theme_id_params
        return unless valid_links?(@note) && valid_note_tags?(tag_ids) &&
                      valid_game_results?(game_result_ids, @note.game_result_ids) &&
                      valid_improvement_themes?(theme_ids, @note.improvement_theme_ids)

        saved = ActiveRecord::Base.transaction do
          next false unless @note.save

          apply_links(@note, tag_ids, game_result_ids, theme_ids)
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

      # 検証済みの ID 群を紐付けへ反映する。nil はキー未送信を表すため反映をスキップし、
      # 既存紐付けを維持する（[] は明示的な全解除）。create では常に配列が渡る。
      def apply_links(note, tag_ids, game_result_ids, theme_ids)
        note.note_tag_ids = tag_ids unless tag_ids.nil?
        note.game_result_ids = game_result_ids unless game_result_ids.nil?
        note.improvement_theme_ids = theme_ids unless theme_ids.nil?
      end

      def load_note
        @note = current_api_v1_user.baseball_notes.find(params[:id])
      end

      def note_params
        params.require(:baseball_note).permit(:title, :date, :memo, :practice_log_id,
                                              :practice_session_id, :reflection_template_id,
                                              reflection_answers: %i[question answer])
      end

      # 試合記録は has_many through の即時保存を避けるため mass-assign せず、
      # 所有・Pro 制限検証後に別途 game_result_ids= で反映する。
      # update 時にキー自体が未送信なら nil を返し反映をスキップする（部分更新で既存紐付けを消さない）。
      def game_result_id_params
        baseball_note_params = params.require(:baseball_note)
        return nil if action_name == 'update' && !baseball_note_params.key?(:game_result_ids)

        baseball_note_params.fetch(:game_result_ids, []).map(&:to_i).uniq
      end

      # 課題は has_many through の即時保存を避けるため mass-assign せず、
      # 所有・Pro 制限検証後に別途 improvement_theme_ids= で反映する。
      # update 時にキー自体が未送信なら nil を返し反映をスキップする（部分更新で既存紐付けを消さない）。
      def improvement_theme_id_params
        baseball_note_params = params.require(:baseball_note)
        return nil if action_name == 'update' && !baseball_note_params.key?(:improvement_theme_ids)

        baseball_note_params.fetch(:improvement_theme_ids, []).map(&:to_i).uniq
      end

      # タグは has_many through の即時保存を避けるため mass-assign せず、
      # 所有・Pro 制限検証後に別途 note_tag_ids= で反映する。
      # 重複IDのまま渡すと ids_writer が同一レコードを二重 add しようとしうるため uniq する。
      # update 時に tag_ids キー自体が未送信なら nil を返しタグ処理自体をスキップする（無料ユーザーは
      # タグ編集UIが非表示になるため、パラメータ省略時に既存タグへ再度Pro判定をかけて消してしまわないようにする）。
      def tag_id_params
        baseball_note_params = params.require(:baseball_note)
        return nil if action_name == 'update' && !baseball_note_params.key?(:tag_ids)

        baseball_note_params.fetch(:tag_ids, []).map(&:to_i).uniq
      end

      # 紐付け先カラム => { association:, error: } の対応。所有検証（IDOR 防止）に使う。
      LINK_OWNERSHIPS = {
        practice_log_id: { association: :practice_logs, error: '不正な練習の指定です' },
        practice_session_id: { association: :practice_sessions, error: '不正な練習記録の指定です' }
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

      # タグはプリセット or 自作のみ付与可（他ユーザーの自作は不可）。タグ付与自体が Pro 限定機能。
      def valid_note_tags?(tag_ids)
        return true if tag_ids.blank?

        unless current_api_v1_user.has_entitlement?('note_tags')
          render json: { error: 'タグ機能は Pro プラン限定です' }, status: :forbidden
          return false
        end
        return true if ::NoteTag.available_for(current_api_v1_user).where(id: tag_ids).count == tag_ids.uniq.size

        render json: { error: '不正なタグの指定です' }, status: :forbidden
        false
      end

      # 他ユーザーの試合には紐付けられない（IDOR 防止）。無料は1件、Pro は複数件紐付け可。
      # existing_ids は更新前の既存紐付け。Pro 解約後も既存の複数紐付けを維持・削減できるよう、
      # 既存件数を超えて新規に増やす場合のみ Pro 判定する（グランドファザリング）。
      def valid_game_results?(game_result_ids, existing_ids = [])
        return true if game_result_ids.blank?

        if game_result_ids.size > 1 && game_result_ids.size > existing_ids.size &&
           !current_api_v1_user.has_entitlement?('multi_game_result_notes')
          render json: { error: '複数の試合記録への紐付けは Pro プラン限定です' }, status: :forbidden
          return false
        end
        return true if current_api_v1_user.game_results.where(id: game_result_ids).count == game_result_ids.uniq.size

        render json: { error: '不正な試合の指定です' }, status: :forbidden
        false
      end

      # 他ユーザーの課題には紐付けられない（IDOR 防止）。無料は1件、Pro は複数件紐付け可。
      # existing_ids は更新前の既存紐付け。Pro 解約後も既存の複数紐付けを維持・削減できるよう、
      # 既存件数を超えて新規に増やす場合のみ Pro 判定する（グランドファザリング）。
      def valid_improvement_themes?(theme_ids, existing_ids = [])
        return true if theme_ids.blank?

        if theme_ids.size > 1 && theme_ids.size > existing_ids.size &&
           !current_api_v1_user.has_entitlement?('multi_improvement_theme_links')
          render json: { error: '複数の課題への紐付けは Pro プラン限定です' }, status: :forbidden
          return false
        end
        return true if current_api_v1_user.improvement_themes.where(id: theme_ids).count == theme_ids.uniq.size

        render json: { error: '不正な課題の指定です' }, status: :forbidden
        false
      end
    end
  end
end
