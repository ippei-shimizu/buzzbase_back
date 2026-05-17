class Subscription < ApplicationRecord
  belongs_to :user
  has_many :user_subscription_events, dependent: :nullify

  STATUSES = %w[free trial active cancelled billing_issue expired pending].freeze
  PRO_ACTIVE_STATUSES = %w[trial active cancelled billing_issue].freeze
  GRACE_STATUSES = %w[cancelled billing_issue].freeze

  enum status: STATUSES.index_with(&:itself)
  enum plan_type: { monthly: 'monthly', yearly: 'yearly' }, _prefix: :plan
  enum platform: { ios: 'ios', web: 'web', android: 'android' }, _prefix: :platform

  validates :status, inclusion: { in: STATUSES }

  # Pro 機能が利用可能か。
  # 期限内かつ status が trial / active / cancelled / billing_issue のとき true。
  # @return [Boolean]
  def pro_active?
    return false unless PRO_ACTIVE_STATUSES.include?(status)

    expires_at.nil? || expires_at > Time.current
  end

  # トライアル期間中か。
  # @return [Boolean]
  def in_trial?
    trial? && (expires_at.nil? || expires_at > Time.current)
  end

  # グレースピリオド中か（解約済みだが期限内、または課金失敗中）。
  # @return [Boolean]
  def in_grace_period?
    GRACE_STATUSES.include?(status)
  end

  # 期限までの残日数（負数にはならない）。expires_at が nil なら nil を返す。
  # @return [Integer, nil]
  def days_remaining
    return nil unless expires_at

    [(expires_at.to_date - Date.current).to_i, 0].max
  end

  # トライアル利用可能か。1ユーザー1回までの制約を表現する。
  # @return [Boolean]
  def can_use_trial?
    !has_used_trial?
  end
end
