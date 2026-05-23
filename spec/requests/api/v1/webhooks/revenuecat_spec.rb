require 'rails_helper'

RSpec.describe 'Api::V1::Webhooks::Revenuecat', type: :request do
  let(:secret) { 'rc_test_secret_xyz' }
  let(:auth_header) { { 'Authorization' => "Bearer #{secret}" } }
  let(:event_id) { 'evt_initial_purchase_001' }
  let(:payload) do
    {
      event: {
        id: event_id,
        type: 'INITIAL_PURCHASE',
        app_user_id: 'user_1'
      }
    }
  end

  before do
    # 本実装後は ENV['REVENUECAT_WEBHOOK_SECRET'] を参照して HMAC 照合する。
    # 個別 spec が ENV 全体に干渉しないよう、Authorization ヘッダで使う secret だけスタブする。
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('REVENUECAT_WEBHOOK_SECRET', any_args).and_return(secret)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('REVENUECAT_WEBHOOK_SECRET').and_return(secret)
  end

  describe 'POST /api/v1/webhooks/revenuecat' do
    context '署名（Authorization Bearer）が一致するとき' do
      it '200 を返し、pending な WebhookEvent を作成して Job を enqueue する' do
        expect do
          post '/api/v1/webhooks/revenuecat', params: payload, headers: auth_header, as: :json
        end.to have_enqueued_job(RevenueCatWebhookJob).exactly(:once)

        expect(response).to have_http_status(:ok)
        event = WebhookEvent.find_by(provider: 'revenuecat', external_event_id: event_id)
        expect(event).to be_present
        expect(event.status).to eq('pending')
        expect(event.event_type).to eq('INITIAL_PURCHASE')
      end

      context '同一 event_id を 2 回送信したとき' do
        it '2 回目は Job を enqueue しない（冪等性）' do
          post '/api/v1/webhooks/revenuecat', params: payload, headers: auth_header, as: :json

          expect do
            post '/api/v1/webhooks/revenuecat', params: payload, headers: auth_header, as: :json
          end.not_to have_enqueued_job(RevenueCatWebhookJob)

          expect(response).to have_http_status(:ok)
          expect(WebhookEvent.where(provider: 'revenuecat', external_event_id: event_id).count).to eq(1)
        end
      end
    end

    context '署名が一致しないとき' do
      it '401 を返し、WebhookEvent を作らず Job も enqueue しない' do
        expect do
          post '/api/v1/webhooks/revenuecat',
               params: payload,
               headers: { 'Authorization' => 'Bearer wrong-secret' },
               as: :json
        end.not_to have_enqueued_job(RevenueCatWebhookJob)

        expect(response).to have_http_status(:unauthorized)
        expect(WebhookEvent.count).to eq(0)
      end
    end

    context 'Authorization ヘッダ自体がないとき' do
      it '401 を返す' do
        post '/api/v1/webhooks/revenuecat', params: payload, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'payload に event.id が無いとき' do
      it '422 を返し、Sentry に通知する' do
        allow(Sentry).to receive(:capture_message)

        post '/api/v1/webhooks/revenuecat',
             params: { event: { type: 'INITIAL_PURCHASE' } },
             headers: auth_header,
             as: :json

        expect(Sentry).to have_received(:capture_message).with(
          a_string_including('event.id missing'),
          hash_including(level: :warning)
        )
        expect(response).to have_http_status(:unprocessable_entity)
        expect(WebhookEvent.count).to eq(0)
      end
    end

    context 'WebhookEvent の作成中に DB エラーが発生したとき' do
      it 'Sentry に通知し、500 を返す（RevenueCat 側の自動リトライに任せる）' do
        allow(WebhookEvent).to receive(:find_or_create_pending!).and_raise(ActiveRecord::ConnectionNotEstablished, 'db down')
        allow(Sentry).to receive(:capture_exception)

        post '/api/v1/webhooks/revenuecat', params: payload, headers: auth_header, as: :json

        expect(Sentry).to have_received(:capture_exception)
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
