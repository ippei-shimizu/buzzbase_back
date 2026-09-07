require 'rails_helper'

RSpec.describe 'Api::V1::Pro::Checkout', type: :request do
  let(:user) { create(:user) }
  let(:params) do
    {
      plan: 'monthly',
      success_url: 'https://buzzbase.jp/pro/success',
      cancel_url: 'https://buzzbase.jp/pro/cancel'
    }
  end

  describe 'POST /api/v1/pro/checkout' do
    context '未認証のとき' do
      it '401 を返す' do
        post '/api/v1/pro/checkout', params:, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context '認証済みかつ未加入のとき' do
      let(:stripe_session) { instance_double(Stripe::Checkout::Session, url: 'https://checkout.stripe.com/c/pay/sess_abc') }
      let(:builder) { instance_double(App::Stripe::CheckoutSessionBuilder, call: stripe_session) }

      before { allow(App::Stripe::CheckoutSessionBuilder).to receive(:new).and_return(builder) }

      it 'checkout_url を含む 200 レスポンスを返す' do
        post '/api/v1/pro/checkout', params:, headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['checkout_url']).to eq('https://checkout.stripe.com/c/pay/sess_abc')
      end
    end

    context '既加入で AlreadySubscribedError が起きるとき' do
      let(:builder) { instance_double(App::Stripe::CheckoutSessionBuilder) }

      before do
        allow(App::Stripe::CheckoutSessionBuilder).to receive(:new).and_return(builder)
        allow(builder).to receive(:call).and_raise(App::Stripe::CheckoutSessionBuilder::AlreadySubscribedError)
      end

      it '409 + error: already_subscribed を返す' do
        post '/api/v1/pro/checkout', params:, headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:conflict)
        expect(response.parsed_body['error']).to eq('already_subscribed')
      end
    end

    context '不正な plan で InvalidPlanError が起きるとき' do
      let(:builder) { instance_double(App::Stripe::CheckoutSessionBuilder) }

      before do
        allow(App::Stripe::CheckoutSessionBuilder).to receive(:new).and_return(builder)
        allow(builder).to receive(:call).and_raise(App::Stripe::CheckoutSessionBuilder::InvalidPlanError)
      end

      it '422 + error: invalid_plan を返す' do
        post '/api/v1/pro/checkout', params: params.merge(plan: 'lifetime'),
                                     headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('invalid_plan')
      end
    end

    context 'Stripe API エラー（API キー誤設定・ネット障害等）が起きるとき' do
      let(:builder) { instance_double(App::Stripe::CheckoutSessionBuilder) }

      before do
        allow(App::Stripe::CheckoutSessionBuilder).to receive(:new).and_return(builder)
        allow(builder).to receive(:call).and_raise(Stripe::APIConnectionError.new('connection refused'))
        allow(Sentry).to receive(:capture_exception)
      end

      it '502 + error: stripe_api_error を返し、Sentry に通知する' do
        post '/api/v1/pro/checkout', params:, headers: auth_headers_for(user), as: :json
        expect(response).to have_http_status(:bad_gateway)
        expect(response.parsed_body['error']).to eq('stripe_api_error')
        expect(Sentry).to have_received(:capture_exception).with(be_a(Stripe::StripeError), anything)
      end
    end
  end
end
