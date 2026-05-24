require 'rails_helper'

RSpec.describe 'Api::V1::Pro::Subscription', type: :request do
  let(:user) { create(:user) }

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
        allow_any_instance_of(App::Stripe::SubscriptionUpdater).to receive(:cancel_at_period_end)
      end

      it '200 を返す' do
        delete '/api/v1/pro/subscription', headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context 'Stripe Subscription 未紐付' do
      before do
        allow_any_instance_of(App::Stripe::SubscriptionUpdater)
          .to receive(:cancel_at_period_end)
          .and_raise(App::Stripe::SubscriptionUpdater::NoStripeSubscriptionError)
      end

      it '422 + error: no_active_subscription を返す' do
        delete '/api/v1/pro/subscription', headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('no_active_subscription')
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
        allow_any_instance_of(App::Stripe::SubscriptionUpdater).to receive(:change_plan).with('yearly')
      end

      it '200 を返す' do
        patch '/api/v1/pro/subscription', params: { plan: 'yearly' },
                                          headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context '不正な plan' do
      before do
        allow_any_instance_of(App::Stripe::SubscriptionUpdater)
          .to receive(:change_plan)
          .and_raise(App::Stripe::SubscriptionUpdater::InvalidPlanError)
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
        allow_any_instance_of(App::Stripe::SubscriptionUpdater)
          .to receive(:change_plan)
          .and_raise(App::Stripe::SubscriptionUpdater::NoStripeSubscriptionError)
      end

      it '422 + error: no_active_subscription を返す' do
        patch '/api/v1/pro/subscription', params: { plan: 'yearly' },
                                          headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('no_active_subscription')
      end
    end
  end
end
