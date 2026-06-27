module V2
  # 日次の練習セッション。その日の量ログ（メニュー項目）とコンディションを束ねて返す。
  class PracticeSessionSerializer < ActiveModel::Serializer
    attributes :id, :logged_on, :memo, :created_at

    has_many :practice_logs, serializer: V2::PracticeLogSerializer

    attribute :condition do
      log = object.condition_log
      log && V2::ConditionLogSerializer.new(log).as_json
    end
  end
end
