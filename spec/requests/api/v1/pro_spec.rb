require 'rails_helper'

RSpec.describe 'Api::V1::Pro', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v1/pro/status' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get '/api/v1/pro/status'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as a free user' do
      it 'returns subscription with status free and free-only entitlements' do
        get '/api/v1/pro/status', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['subscription']['status']).to eq 'free'
        expect(json['subscription']['pro_active']).to be false
        expect(json['subscription']['in_trial']).to be false
        expect(json['subscription']['in_grace_period']).to be false
        expect(json['entitlements']).to include('basic_game_record')
        expect(json['entitlements']).not_to include('season_transition_graph')
      end
    end

    context 'when authenticated as a Pro user' do
      before do
        user.subscription.update!(status: 'active', expires_at: 30.days.from_now, plan_type: 'monthly', platform: 'ios')
      end

      it 'returns active subscription and includes Pro entitlements' do
        get '/api/v1/pro/status', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['subscription']['status']).to eq 'active'
        expect(json['subscription']['pro_active']).to be true
        expect(json['subscription']['days_remaining']).to be > 0
        expect(json['entitlements']).to include('season_transition_graph', 'no_ads', 'basic_game_record')
      end
    end
  end

  describe 'POST /api/v1/pro/sync' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post '/api/v1/pro/sync'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      it 'fetches the current RevenueCat subscriber state, updates last_synced_at, and returns it' do
        allow(RevenueCat::SubscriberClient).to receive(:fetch_subscriber).with(user.id.to_s).and_return({})

        expect do
          post '/api/v1/pro/sync', headers: auth_headers_for(user)
        end.to change { user.subscription.reload.last_synced_at }.from(nil)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['subscription']['status']).to eq 'free'
        expect(json['entitlements']).to be_an(Array)
      end

      it 'reflects an active RevenueCat entitlement into the subscription' do
        allow(RevenueCat::SubscriberClient).to receive(:fetch_subscriber).with(user.id.to_s).and_return(
          'entitlements' => {
            'pro' => {
              'product_identifier' => 'jp.buzzbase.mobile.pro.monthly',
              'purchase_date' => 1.day.ago.iso8601,
              'expires_date' => 29.days.from_now.iso8601
            }
          },
          'subscriptions' => {
            'jp.buzzbase.mobile.pro.monthly' => { 'store' => 'app_store', 'period_type' => 'NORMAL' }
          }
        )

        post '/api/v1/pro/sync', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['subscription']['status']).to eq 'active'
      end

      it 'returns bad_gateway when the RevenueCat API request fails' do
        allow(RevenueCat::SubscriberClient).to receive(:fetch_subscriber)
          .and_raise(RevenueCat::SubscriberClient::RequestFailedError, 'RevenueCat API returned 500')

        post '/api/v1/pro/sync', headers: auth_headers_for(user)

        expect(response).to have_http_status(:bad_gateway)
        expect(response.parsed_body['error']).to eq 'revenuecat_api_error'
      end
    end
  end

  describe 'GET /api/v1/pro/entitlements' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get '/api/v1/pro/entitlements'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as a free user' do
      it 'returns granted=true for free features and granted=false for Pro features' do
        get '/api/v1/pro/entitlements', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        entitlements = response.parsed_body['entitlements']
        expect(entitlements.size).to eq Entitlement::ALL_FEATURES.size

        free_entry = entitlements.find { |e| e['key'] == 'basic_game_record' }
        pro_entry = entitlements.find { |e| e['key'] == 'season_transition_graph' }
        expect(free_entry['granted']).to be true
        expect(pro_entry['granted']).to be false
      end
    end
  end
end
