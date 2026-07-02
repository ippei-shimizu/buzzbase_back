module V2
  # 週次 / 月次レポート。基本部（練習量・Streak）は全員に、詳細部（課題別内訳・
  # コンディション・成績前週比・相関）は Pro のみに返す。出し分けは instance_options[:pro]。
  class PeriodicReviewSerializer < ActiveModel::Serializer
    attributes :id, :period_type, :period_start, :period_end, :read, :summary

    def summary
      return object.summary if instance_options[:pro]

      object.summary.except(*PeriodicReview::ADVANCED_SUMMARY_KEYS)
    end
  end
end
