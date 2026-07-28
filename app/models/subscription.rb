class Subscription < ApplicationRecord
  belongs_to :user
  has_many :user_subscription_events, dependent: :nullify

  STATUSES = %w[free trial active cancelled billing_issue expired pending].freeze
  PRO_ACTIVE_STATUSES = %w[trial active cancelled billing_issue].freeze
  GRACE_STATUSES = %w[cancelled billing_issue].freeze

  # status の取りうる値:
  # - free          : 一度も加入していない、または完全期限切れ
  # - trial         : トライアル期間中（期限内）
  # - active        : 通常課金中（期限内）
  # - cancelled     : 解約申請済み、期限まで利用可
  # - billing_issue : 課金失敗、Grace Period 中
  # - expired       : 期限切れ、Pro 機能不可
  # - pending       : 課金処理中の遷移状態。Pro 機能は不可（PRO_ACTIVE_STATUSES に含めない）
  enum status: {
    free: 'free',
    trial: 'trial',
    active: 'active',
    cancelled: 'cancelled',
    billing_issue: 'billing_issue',
    expired: 'expired',
    pending: 'pending'
  }
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

  # グレースピリオド中か（解約済みだが期限内、または課金失敗中で期限内）。
  # 「期限切れの cancelled / billing_issue」は無料状態と見なすため false を返す。
  # クライアントはこのフラグを Pro アクセス判定に直接使ってよい。
  # @return [Boolean]
  def in_grace_period?
    return false unless GRACE_STATUSES.include?(status)

    expires_at.nil? || expires_at > Time.current
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
