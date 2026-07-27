module V2
  class BaseballNoteSerializer < ActiveModel::Serializer
    attributes :id, :title, :date, :memo, :memo_preview, :game_result_ids, :practice_log_id, :practice_session_id,
               :improvement_theme_ids, :reflection_template_id, :reflection_answers, :tags

    has_many :media_attachments, serializer: ::V2::MediaAttachmentSerializer

    def memo_preview
      object.extract_and_truncate_memo
    end

    def game_result_ids
      # includes(:game_results) 済みの前提で N+1 を避ける。
      object.game_results.map(&:id)
    end

    def improvement_theme_ids
      # includes(:improvement_themes) 済みの前提で N+1 を避ける。
      object.improvement_themes.map(&:id)
    end

    def tags
      # スコープをチェーンすると includes(:note_tags) の preload が無効化され N+1 になるため、メモリ上で並べる。
      object.note_tags.sort_by { |tag| [tag.sort_order, tag.id] }
            .map { |tag| { id: tag.id, name: tag.name, is_preset: tag.is_preset } }
    end
  end
end
