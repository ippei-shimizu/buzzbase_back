module RevenueCat
  module Handlers
    # BILLING_ISSUE は課金失敗。Grace Period 中は Pro 機能利用可なので expires_at は変えない。
    class BillingIssueHandler < BaseHandler
      def call
        with_resolved_subscription do |user, subscription|
          # Job リトライによる時刻ズレを避けるため、billing_issue_at は Webhook payload のイベント時刻を採用する。
          subscription.update!(
            status: 'billing_issue',
            billing_issue_at: payload.event_timestamp || Time.current,
            last_synced_at: Time.current
          )
          event_recorder.record(user, subscription, 'billing_issue')
          BillingIssueNotificationJob.perform_now(user.id)
        end
      end
    end
  end
end
