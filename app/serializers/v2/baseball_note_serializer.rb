module V2
  class BaseballNoteSerializer < ActiveModel::Serializer
    attributes :id, :title, :date, :memo, :memo_preview, :game_result_id, :practice_log_id

    def memo_preview
      object.extract_and_truncate_memo
    end
  end
end
