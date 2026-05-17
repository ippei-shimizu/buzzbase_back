# Pro 加入状態に関する監査ログ。
# 書き込みロジック（Webhook 受信時の event 記録）は #318 で実装する。
# 本 Issue ではモデルクラスのみ用意し、Subscription / User からの関連を成立させる。
class UserSubscriptionEvent < ApplicationRecord
  belongs_to :user
  belongs_to :subscription, optional: true

  EVENT_TYPES = %w[
    trial_started
    purchased
    renewed
    cancelled
    expired
    refunded
    billing_issue
    recovered
  ].freeze

  validates :event_type, presence: true
  validates :occurred_at, presence: true
end
