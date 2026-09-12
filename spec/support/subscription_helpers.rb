module SubscriptionHelpers
  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 30.days.from_now)
  end
end
