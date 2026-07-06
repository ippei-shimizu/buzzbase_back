module V2
  class BaseballNoteSerializer < ActiveModel::Serializer
    attributes :id, :title, :date, :memo, :memo_preview, :game_result_id, :practice_log_id, :practice_session_id,
               :improvement_theme_id, :reflection_template_id, :reflection_answers, :tags

    def memo_preview
      object.extract_and_truncate_memo
    end

    def tags
      object.note_tags.ordered.map { |tag| { id: tag.id, name: tag.name, is_preset: tag.is_preset } }
    end
  end
end
