module RevenueCat
  module Handlers
    # BILLING_ISSUE は課金失敗。Grace Period 中は Pro 機能利用可なので expires_at は変えない。
    class BillingIssueHandler < BaseHandler
      def call
        with_resolved_subscription do |user, subscription|
          subscription.update!(
            status: 'billing_issue',
            billing_issue_at: Time.current,
            last_synced_at: Time.current
          )
          event_recorder.record(user, 'billing_issue')
        end
      end
    end
  end
end
