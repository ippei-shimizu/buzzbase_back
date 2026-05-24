require 'rails_helper'

RSpec.describe 'Api::V1::Webhooks::Stripe', type: :request do
  let(:secret) { 'whsec_test_xyz' }
  let(:raw_payload) do
    Rails.root.join('spec/fixtures/stripe/checkout_session_completed.json').read
  end
  let(:event_id) { 'evt_test_checkout_completed_001' }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('STRIPE_WEBHOOK_SECRET').and_return(secret)
  end

  # construct_event をスタブして、本物の Stripe::Event を返す or 例外を投げる
  def stub_event_construction(success:)
    if success
      event = Stripe::Event.construct_from(JSON.parse(raw_payload))
      allow(Stripe::Webhook).to receive(:construct_event).and_return(event)
    else
      allow(Stripe::Webhook).to receive(:construct_event)
        .and_raise(Stripe::SignatureVerificationError.new('invalid sig', 'sig_header'))
    end
  end

  describe 'POST /api/v1/webhooks/stripe' do
    context '署名検証通過 + 新規 event のとき' do
      before { stub_event_construction(success: true) }

      it '200 を返し、WebhookEvent を作成して Job を enqueue する' do
        expect do
          post '/api/v1/webhooks/stripe',
               params: raw_payload,
               headers: { 'CONTENT_TYPE' => 'application/json', 'Stripe-Signature' => 't=1,v1=abc' }
        end.to have_enqueued_job(App::Stripe::WebhookJob).exactly(:once)

        expect(response).to have_http_status(:ok)
        event = WebhookEvent.find_by(provider: 'stripe', external_event_id: event_id)
        expect(event).to be_present
        expect(event.status).to eq('pending')
      end

      context '同一 event_id を 2 回送信したとき' do
        it '2 回目は Job を enqueue しない（冪等性）' do
          post '/api/v1/webhooks/stripe',
               params: raw_payload,
               headers: { 'CONTENT_TYPE' => 'application/json', 'Stripe-Signature' => 't=1,v1=abc' }

          expect do
            post '/api/v1/webhooks/stripe',
                 params: raw_payload,
                 headers: { 'CONTENT_TYPE' => 'application/json', 'Stripe-Signature' => 't=1,v1=abc' }
          end.not_to have_enqueued_job(App::Stripe::WebhookJob)

          expect(response).to have_http_status(:ok)
          expect(WebhookEvent.where(provider: 'stripe', external_event_id: event_id).count).to eq(1)
        end
      end
    end

    context '署名検証失敗のとき' do
      before { stub_event_construction(success: false) }

      it '401 を返し、Job を enqueue しない' do
        expect do
          post '/api/v1/webhooks/stripe',
               params: raw_payload,
               headers: { 'CONTENT_TYPE' => 'application/json', 'Stripe-Signature' => 'invalid' }
        end.not_to have_enqueued_job(App::Stripe::WebhookJob)

        expect(response).to have_http_status(:unauthorized)
        expect(WebhookEvent.count).to eq(0)
      end
    end

    context 'WebhookEvent の作成中に DB エラーが発生したとき' do
      before do
        stub_event_construction(success: true)
        allow(WebhookEvent).to receive(:find_or_create_pending!).and_raise(ActiveRecord::ConnectionNotEstablished, 'db down')
        allow(Sentry).to receive(:capture_exception)
      end

      it 'Sentry 通知 + 500 を返す（Stripe 側の自動リトライに任せる）' do
        post '/api/v1/webhooks/stripe',
             params: raw_payload,
             headers: { 'CONTENT_TYPE' => 'application/json', 'Stripe-Signature' => 't=1,v1=abc' }

        expect(Sentry).to have_received(:capture_exception)
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
