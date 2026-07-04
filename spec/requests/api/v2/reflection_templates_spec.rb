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

  describe 'PATCH /api/v2/reflection_templates/:id' do
    let(:params) { { reflection_template: { title: '改訂版', questions: %w[新しい問い] } } }

    it '自作の編集は原本を更新せず新バージョンを作り、旧版は一覧から消える' do
      mine = create(:reflection_template, user:, title: '元テンプレ', questions: %w[旧問い])
      patch "/api/v2/reflection_templates/#{mine.id}", params:, headers: auth_headers_for(user)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      aggregate_failures do
        expect(body['id']).not_to eq(mine.id)
        expect(body['title']).to eq('改訂版')
        mine.reload
        expect(mine.title).to eq('元テンプレ')
        expect(mine.archived_at).to be_present
      end

      get '/api/v2/reflection_templates', headers: auth_headers_for(user)
      ids = response.parsed_body.pluck('id')
      aggregate_failures do
        expect(ids).to include(body['id'])
        expect(ids).not_to include(mine.id)
      end
    end

    it 'プリセット編集は共有プリセットを変えずユーザー専用コピーを作る（他ユーザーに影響しない）' do
      preset = create(:reflection_template, :preset, title: 'プリセットA', questions: %w[問1])
      other = create(:user)

      patch "/api/v2/reflection_templates/#{preset.id}", params:, headers: auth_headers_for(user)
      copy_id = response.parsed_body['id']

      get '/api/v2/reflection_templates', headers: auth_headers_for(user)
      my_ids = response.parsed_body.pluck('id')
      get '/api/v2/reflection_templates', headers: auth_headers_for(other)
      other_ids = response.parsed_body.pluck('id')

      aggregate_failures do
        expect(preset.reload.title).to eq('プリセットA')
        expect(my_ids).to include(copy_id)
        expect(my_ids).not_to include(preset.id)
        expect(other_ids).to include(preset.id)
        expect(other_ids).not_to include(copy_id)
      end
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

    it 'ノートで使用中のテンプレは削除できない（422）' do
      mine = create(:reflection_template, user:)
      create(:baseball_note, user:, reflection_template: mine)

      delete "/api/v2/reflection_templates/#{mine.id}", headers: auth_headers_for(user)

      aggregate_failures do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(ReflectionTemplate.exists?(mine.id)).to be true
      end
    end
  end
end
