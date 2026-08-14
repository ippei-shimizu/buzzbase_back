require 'rails_helper'

RSpec.describe 'Api::V1::Pro::Subscription', type: :request do
  let(:user) { create(:user) }
  let(:updater) { instance_double(App::Stripe::SubscriptionUpdater) }

  before do
    allow(App::Stripe::SubscriptionUpdater).to receive(:new).and_return(updater)
  end

  describe 'DELETE /api/v1/pro/subscription' do
    context '未認証のとき' do
      it '401 を返す' do
        delete '/api/v1/pro/subscription', as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context '認証済みかつ Stripe Subscription 紐付け済み' do
      before do
        user.subscription.update!(stripe_subscription_id: 'sub_test_abc')
        allow(updater).to receive(:cancel_at_period_end)
      end

      it '200 + 解約申請メッセージを返す' do
        delete '/api/v1/pro/subscription', headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['message']).to eq('解約申請を受け付けました')
      end
    end

    context 'Stripe Subscription 未紐付' do
      before do
        allow(updater).to receive(:cancel_at_period_end).and_raise(App::Stripe::SubscriptionUpdater::NoStripeSubscriptionError)
      end

      it '422 + error: no_active_subscription を返す' do
        delete '/api/v1/pro/subscription', headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('no_active_subscription')
      end
    end

    context 'Stripe API エラーが起きるとき' do
      before do
        allow(updater).to receive(:cancel_at_period_end).and_raise(Stripe::APIConnectionError.new('boom'))
        allow(Sentry).to receive(:capture_exception)
      end

      it '502 + error: stripe_api_error を返し Sentry 通知' do
        delete '/api/v1/pro/subscription', headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:bad_gateway)
        expect(response.parsed_body['error']).to eq('stripe_api_error')
        expect(Sentry).to have_received(:capture_exception)
      end
    end
  end

  describe 'PATCH /api/v1/pro/subscription' do
    context '未認証のとき' do
      it '401 を返す' do
        patch '/api/v1/pro/subscription', params: { plan: 'yearly' }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context '正常なプラン変更リクエスト' do
      before do
        user.subscription.update!(stripe_subscription_id: 'sub_test_abc')
        allow(updater).to receive(:change_plan).with('yearly')
      end

      it '200 + プラン変更メッセージを返す' do
        patch '/api/v1/pro/subscription', params: { plan: 'yearly' },
                                          headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['message']).to eq('プラン変更を受け付けました')
      end
    end

    context '不正な plan' do
      before do
        allow(updater).to receive(:change_plan).and_raise(App::Stripe::SubscriptionUpdater::InvalidPlanError)
      end

      it '422 + error: invalid_plan を返す' do
        patch '/api/v1/pro/subscription', params: { plan: 'lifetime' },
                                          headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('invalid_plan')
      end
    end

    context 'Stripe Subscription 未紐付' do
      before do
        allow(updater).to receive(:change_plan).and_raise(App::Stripe::SubscriptionUpdater::NoStripeSubscriptionError)
      end

      it '422 + error: no_active_subscription を返す' do
        patch '/api/v1/pro/subscription', params: { plan: 'yearly' },
                                          headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('no_active_subscription')
      end
    end

    context 'Stripe API エラーが起きるとき' do
      before do
        allow(updater).to receive(:change_plan).and_raise(Stripe::APIConnectionError.new('boom'))
        allow(Sentry).to receive(:capture_exception)
      end

      it '502 + error: stripe_api_error を返し Sentry 通知' do
        patch '/api/v1/pro/subscription', params: { plan: 'yearly' },
                                          headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:bad_gateway)
        expect(response.parsed_body['error']).to eq('stripe_api_error')
        expect(Sentry).to have_received(:capture_exception)
      end
    end
  end
end
