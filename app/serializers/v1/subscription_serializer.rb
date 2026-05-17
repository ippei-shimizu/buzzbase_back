module V1
  # /api/v1/pro/status から返却する subscription 部分のシリアライザ。
  # フロント・モバイル共通の Pro 状態判定の根拠となるため、
  # クライアントの pro_active? と同じロジックをここで露出させる。
  class SubscriptionSerializer < ActiveModel::Serializer
    attributes :status, :plan_type, :platform,
               :started_at, :expires_at,
               :pro_active, :in_trial, :in_grace_period, :days_remaining,
               :is_early_subscriber, :has_used_trial

    # @return [Boolean] 期限内かつ Pro 加入扱いの status か
    def pro_active
      object.pro_active?
    end

    # @return [Boolean]
    def in_trial
      object.in_trial?
    end

    # @return [Boolean]
    def in_grace_period
      object.in_grace_period?
    end

    # @return [Integer, nil]
    delegate :days_remaining, to: :object
  end
end
