module Api
  module V1
    module Webhooks
      # POST /api/v1/webhooks/revenuecat
      # RevenueCat からの Webhook 受信エンドポイント。
      # 10 秒以内の 200 OK 返却が求められるため、本処理は Solid Queue 経由で非同期化する。
      # 冪等性は webhook_events テーブルの (provider, external_event_id) UNIQUE 制約に委ねる。
      class RevenuecatController < ApplicationController
        skip_before_action :verify_authenticity_token, raise: false
        before_action :verify_signature!

        def create
          event_params = params[:event]
          event_id = event_params.is_a?(ActionController::Parameters) || event_params.is_a?(Hash) ? event_params[:id] : nil

          if event_id.blank?
            Sentry.capture_message('RevenueCat webhook: event.id missing in payload', level: :warning)
            return head :unprocessable_entity
          end

          event_type = event_params[:type]

          webhook_event = WebhookEvent.find_or_create_pending!(
            provider: 'revenuecat',
            external_event_id: event_id,
            event_type:,
            payload: params.to_unsafe_h
          )

          # 既存レコードが返ったときは既にジョブが enqueue 済み（冪等性）。
          # 新規作成時だけ pending な状態でジョブを enqueue する。
          RevenueCatWebhookJob.perform_later(webhook_event.id) if webhook_event.previously_new_record?

          head :ok
        rescue StandardError => e
          Sentry.capture_exception(e, tags: { source: 'revenuecat_webhook_controller' })
          head :internal_server_error
        end

        private

        # Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET> を期待する。
        # 共有秘密のタイミング攻撃を避けるため、長さを揃えてから secure_compare する。
        def verify_signature!
          expected = "Bearer #{ENV.fetch('REVENUECAT_WEBHOOK_SECRET', nil)}"
          provided = request.headers['Authorization'].to_s
          return if provided.bytesize == expected.bytesize &&
                    ActiveSupport::SecurityUtils.secure_compare(provided, expected)

          head :unauthorized
        end
      end
    end
  end
end
