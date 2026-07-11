module V2
  # 日次の練習セッション。その日の量ログ（メニュー項目）とコンディションを束ねて返す。
  # `condition_logs_by_date`（logged_on => ConditionLog）を instance_options で受け取ると
  # それを使う（一覧表示での N+1 防止）。無ければ個別に 1 件取得する（show 等の単発表示用）。
  class PracticeSessionSerializer < ActiveModel::Serializer
    attributes :id, :logged_on, :memo, :improvement_theme_id, :created_at

    has_many :practice_logs, serializer: V2::PracticeLogSerializer

    attribute :condition do
      log = preloaded_condition_logs? ? instance_options[:condition_logs_by_date][object.logged_on] : object.condition_log
      log && V2::ConditionLogSerializer.new(log).as_json
    end

    private

    def preloaded_condition_logs?
      instance_options.key?(:condition_logs_by_date)
    end
  end
end
