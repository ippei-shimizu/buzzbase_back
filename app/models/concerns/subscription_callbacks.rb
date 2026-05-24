# Subscription 関連の User コールバックを集約する concern。
# User 本体の責務肥大化を避け、Subscription 関連の挙動を 1 箇所で見られるようにする。
module SubscriptionCallbacks
  extend ActiveSupport::Concern

  included do
    before_destroy :prevent_destroy_if_pro_active
    after_create :create_default_subscription
    after_update :sync_stripe_customer_email, if: :saved_change_to_email?
  end

  private

  # subscription が無いユーザー（コールバック前のレコード等）でも nil 安全に動作させる。
  def create_default_subscription
    return if subscription.present?

    create_subscription!(status: 'free')
  end

  # Pro 加入中ユーザーの削除を防ぐ。Apple/Stripe 側の自動課金が継続するため、
  # 先に解約してもらってから削除させる。Controller でも事前判定するが二重防御として model にもガード。
  def prevent_destroy_if_pro_active
    return unless subscription&.pro_active?

    errors.add(:base, 'Pro 加入中のため、先に解約してください')
    throw :abort
  end

  # email 変更時に Stripe Customer.email を追従させる。
  # iOS / Android ユーザーは Apple ID / Google アカウント側で管理されるため対象外。
  # 同期実行だが Job 内で rescue しているため User#update! を巻き込まない。
  def sync_stripe_customer_email
    return unless subscription&.platform_web?
    return if subscription.stripe_customer_id.blank?

    StripeCustomerUpdateJob.new.perform(id)
  end
end
