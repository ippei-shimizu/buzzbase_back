require 'rails_helper'

RSpec.describe 'Api::V2::ReflectionTemplates', type: :request do
  let(:user) { create(:user) }

  def make_pro(target)
    target.subscription.update!(status: 'active', expires_at: 1.month.from_now)
  end

  describe 'GET /api/v2/reflection_templates' do
    let!(:preset) { create(:reflection_template, :preset) }
    let!(:mine) { create(:reflection_template, user:) }

    context '未認証' do
      it '401' do
        get '/api/v2/reflection_templates'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'プリセットと自作を返す' do
      get '/api/v2/reflection_templates', headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('id')).to include(preset.id, mine.id)
    end
  end

  describe 'POST /api/v2/reflection_templates' do
    let(:params) { { reflection_template: { title: 'マイテンプレ', questions: %w[良かった点 次やること] } } }

    it '自作テンプレを作成できる' do
      post '/api/v2/reflection_templates', params:, headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['questions']).to eq(%w[良かった点 次やること])
      expect(response.parsed_body['is_preset']).to be false
    end

    it '無料は自作2つ目が 403' do
      create(:reflection_template, user:)
      post '/api/v2/reflection_templates', params:, headers: auth_headers_for(user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'Pro は自作を複数作成できる' do
      make_pro(user)
      create(:reflection_template, user:)
      post '/api/v2/reflection_templates', params:, headers: auth_headers_for(user)
      expect(response).to have_http_status(:created)
    end
  end

  describe 'DELETE /api/v2/reflection_templates/:id' do
    it 'プリセットは自分のものではないので 404（削除不可）' do
      preset = create(:reflection_template, :preset)
      delete "/api/v2/reflection_templates/#{preset.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:not_found)
    end

    it '自作は削除できる' do
      mine = create(:reflection_template, user:)
      delete "/api/v2/reflection_templates/#{mine.id}", headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
    end
  end
end
