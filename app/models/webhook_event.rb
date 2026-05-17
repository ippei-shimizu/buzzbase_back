# 外部サービスからの Webhook 受信ログ（冪等性キャッシュ）。
# 書き込みロジックは #318 で実装する。
class WebhookEvent < ApplicationRecord
  STATUSES = %w[pending processed failed skipped].freeze

  validates :provider, presence: true
  validates :external_event_id, presence: true,
                                uniqueness: { scope: :provider }
  validates :status, inclusion: { in: STATUSES }
end
