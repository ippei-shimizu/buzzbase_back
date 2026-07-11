require 'rails_helper'

RSpec.describe 'Api::V2::ImprovementThemes', type: :request do
  let(:user) { create(:user) }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'GET /api/v2/improvement_themes' do
    let!(:open_theme) { create(:improvement_theme, user:, status: 'open') }
    let!(:achieved_theme) { create(:improvement_theme, :achieved, user:) }

    context '未認証' do
      it '401' do
        get '/api/v2/improvement_themes'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it '自分の課題を返す' do
      get '/api/v2/improvement_themes', headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('id')).to contain_exactly(open_theme.id, achieved_theme.id)
    end

    it 'status で絞り込める' do
      get '/api/v2/improvement_themes', params: { status: 'open' }, headers: auth_headers_for(user)
      expect(response.parsed_body.pluck('id')).to contain_exactly(open_theme.id)
    end
  end

  describe 'POST /api/v2/improvement_themes' do
    it '課題を作成できる' do
      post '/api/v2/improvement_themes',
           params: { improvement_theme: { title: '肩の開きを抑える', category: 'batting' } },
           headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['title']).to eq('肩の開きを抑える')
      expect(response.parsed_body['status']).to eq('open')
    end

    it '無料は取組中2つ目が 403' do
      create(:improvement_theme, user:, status: 'open')
      post '/api/v2/improvement_themes', params: { improvement_theme: { title: '2つ目' } },
                                         headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'Pro は取組中を複数作成できる' do
      make_pro(user)
      create(:improvement_theme, user:, status: 'open')
      post '/api/v2/improvement_themes', params: { improvement_theme: { title: '2つ目' } },
                                         headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH /api/v2/improvement_themes/:id' do
    let!(:theme) { create(:improvement_theme, user:, status: 'open') }

    it '克服（achieved）へ状態遷移できる' do
      patch "/api/v2/improvement_themes/#{theme.id}",
            params: { improvement_theme: { status: 'achieved', achieved_on: Time.zone.today.to_s } },
            headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(theme.reload).to be_achieved
    end
  end

  describe 'DELETE /api/v2/improvement_themes/:id' do
    let!(:theme) { create(:improvement_theme, user:) }

    it '削除できる' do
      delete "/api/v2/improvement_themes/#{theme.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(user.improvement_themes.exists?(theme.id)).to be false
    end
  end
end
