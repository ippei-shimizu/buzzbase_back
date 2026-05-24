# Pro 加入状態に関する監査ログ。Webhook 受信時に各イベントを追記する。
class UserSubscriptionEvent < ApplicationRecord
  belongs_to :user
  belongs_to :subscription, optional: true

  EVENT_TYPES = %w[
    initial_purchase
    trial_started
    purchased
    renewed
    cancelled
    expired
    refunded
    billing_issue
    recovered
    uncancelled
    product_changed
  ].freeze

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true
end
