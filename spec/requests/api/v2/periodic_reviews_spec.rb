require 'rails_helper'

RSpec.describe 'Api::V2::PeriodicReviews', type: :request do
  let(:user) { create(:user) }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'GET /api/v2/periodic_reviews' do
    let(:summary) do
      { 'practice_days' => 5, 'total_swings' => 1500, 'theme_breakdown' => [{ 'title' => '肩の開き' }],
        'batting' => { 'batting_average' => 0.3 } }
    end

    before do
      create(:periodic_review, user:, summary:)
      create(:periodic_review, :monthly, user:, summary:)
    end

    context '未認証' do
      it '401' do
        get '/api/v2/periodic_reviews'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context '無料ユーザー' do
      it '週次のみ返し、詳細部は除外される' do
        get '/api/v2/periodic_reviews', headers: auth_headers_for(user)
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body.pluck('period_type')).to eq(['weekly'])
        expect(body.first['summary']).to include('practice_days')
        expect(body.first['summary']).not_to have_key('theme_breakdown')
        expect(body.first['summary']).not_to have_key('batting')
      end
    end

    context 'Pro ユーザー' do
      it '月次も含め詳細部も返す' do
        make_pro(user)
        get '/api/v2/periodic_reviews', headers: auth_headers_for(user)
        body = response.parsed_body
        expect(body.pluck('period_type')).to contain_exactly('weekly', 'monthly')
        expect(body.first['summary']).to have_key('theme_breakdown')
      end
    end
  end

  describe 'PATCH /api/v2/periodic_reviews/:id' do
    let!(:review) { create(:periodic_review, user:, read: false) }

    it '既読にできる' do
      patch "/api/v2/periodic_reviews/#{review.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(review.reload.read).to be true
    end
  end
end
