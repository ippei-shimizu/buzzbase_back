module Api
  module V1
    module Webhooks
      # POST /api/v1/webhooks/revenuecat
      # 10 秒以内に 200 OK を返す必要があるため、受信時は WebhookEvent への記録だけ済ませてジョブに委譲する。
      # 冪等性は webhook_events の (provider, external_event_id) UNIQUE 制約に委ねる。
      class RevenuecatController < ApplicationController
        skip_before_action :verify_authenticity_token, raise: false
        before_action :verify_signature!

        def create
          event_id = params.dig(:event, :id)

          if event_id.blank?
            Sentry.capture_message('RevenueCat webhook: event.id missing in payload', level: :warning)
            return head :unprocessable_entity
          end

          event_type = params.dig(:event, :type)

          webhook_event = WebhookEvent.find_or_create_pending!(
            provider: 'revenuecat',
            external_event_id: event_id,
            event_type:,
            payload: params.to_unsafe_h
          )

          # 既存レコードが返ったときはジョブも enqueue 済みなので新規作成時のみ起動する。
          RevenueCatWebhookJob.perform_later(webhook_event.id) if webhook_event.previously_new_record?

          head :ok
        rescue StandardError => e
          Sentry.capture_exception(e, tags: { source: 'revenuecat_webhook_controller' })
          head :internal_server_error
        end

        private

        # Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET> を期待する。
        # 長さの違いをタイミング情報として漏らさないよう、両辺を SHA256 で固定長化してから比較する。
        def verify_signature!
          expected = Digest::SHA256.hexdigest("Bearer #{ENV.fetch('REVENUECAT_WEBHOOK_SECRET', nil)}")
          provided = Digest::SHA256.hexdigest(request.headers['Authorization'].to_s)
          return if ActiveSupport::SecurityUtils.fixed_length_secure_compare(provided, expected)

          head :unauthorized
        end
      end
    end
  end
end
