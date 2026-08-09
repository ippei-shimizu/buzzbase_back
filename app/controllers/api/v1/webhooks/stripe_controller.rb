module Api
  module V1
    module Webhooks
      # POST /api/v1/webhooks/stripe
      # 10 秒以内に 200 を返す必要があるため、受信時は WebhookEvent への記録だけ済ませてジョブに委譲する。
      # 冪等性は webhook_events の (provider, external_event_id) UNIQUE 制約に委ねる。
      class StripeController < ApplicationController
        skip_before_action :verify_authenticity_token, raise: false

        def create
          event = verify_and_parse_event
          return head :unauthorized unless event

          webhook_event = WebhookEvent.find_or_create_pending!(
            provider: 'stripe',
            external_event_id: event.id,
            event_type: event.type,
            payload: event.to_hash
          )

          # pending のまま（新規作成 or 前回 enqueue 自体が失敗）なら起動する。
          # processed/failed 済みなら重複 enqueue しない。WebhookProcessor 側の
          # processed ガードもあるため、pending 中の再送で二重 enqueue されても安全。
          App::Stripe::WebhookJob.perform_later(webhook_event.id) if webhook_event.pending?
          head :ok
        rescue StandardError => e
          Sentry.capture_exception(e, tags: { source: 'stripe_webhook_controller' })
          head :internal_server_error
        end

        private

        # ::Stripe::Webhook.construct_event は raw body と Stripe-Signature ヘッダを必要とする。
        # 検証失敗は SignatureVerificationError、JSON 不正は JSON::ParserError を投げる。
        # Rails のミドルウェアが先に body を読み終えているケースに備えて rewind を前置する。
        def verify_and_parse_event
          request.body.rewind
          payload = request.body.read
          sig_header = request.headers['Stripe-Signature']
          ::Stripe::Webhook.construct_event(payload, sig_header, ENV.fetch('STRIPE_WEBHOOK_SECRET'))
        rescue ::Stripe::SignatureVerificationError, JSON::ParserError
          nil
        end
      end
    end
  end
end
