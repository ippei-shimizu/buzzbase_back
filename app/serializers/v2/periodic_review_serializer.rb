module V2
  # 週次 / 月次レポート。振り返りレポート自体が Pro 限定機能で、コントローラー側で
  # 無料ユーザーには対象レコードを渡さない。詳細部（課題別内訳・コンディション・相関）の
  # 除外は Pro ユーザー内での区分けが将来入る場合に備えた防御的な出し分け。
  class PeriodicReviewSerializer < ActiveModel::Serializer
    attributes :id, :period_type, :period_start, :period_end, :read, :summary

    def summary
      return object.summary if instance_options[:pro]

      object.summary.except(*PeriodicReview::ADVANCED_SUMMARY_KEYS)
    end
  end
end
