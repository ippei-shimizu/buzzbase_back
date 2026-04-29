require 'rails_helper'

RSpec.describe 'Api::V1::Teams', type: :request do
  let(:user) { create(:user) }
  let(:prefecture) { Prefecture.create!(name: '東京都') }
  let(:category) { BaseballCategory.create!(name: '高校生') }

  describe 'POST /api/v1/teams' do
    context 'when not authenticated' do
      it 'returns 401' do
        post '/api/v1/teams', params: { team: { name: 'テストチーム' } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid name and master ids' do
      it 'creates the team and returns 201' do
        post '/api/v1/teams',
             params: { team: { name: 'テストチーム', category_id: category.id, prefecture_id: prefecture.id } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json['name']).to eq('テストチーム')
        expect(json['category_id']).to eq(category.id)
        expect(json['prefecture_id']).to eq(prefecture.id)
      end
    end

    context 'with name only (master ids omitted)' do
      it 'creates the team and returns 201' do
        post '/api/v1/teams',
             params: { team: { name: 'チーム名のみ' } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json['name']).to eq('チーム名のみ')
        expect(json['category_id']).to be_nil
        expect(json['prefecture_id']).to be_nil
      end
    end

    context 'when prefecture_id is 0 (BUZZBASE-BACKEND-N regression)' do
      it 'returns 422 instead of raising ForeignKeyViolation' do
        post '/api/v1/teams',
             params: { team: { name: '不正なチーム', category_id: category.id, prefecture_id: 0 } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(Team.where(name: '不正なチーム')).to be_empty
      end
    end

    context 'when category_id is 0' do
      it 'returns 422 instead of raising ForeignKeyViolation' do
        post '/api/v1/teams',
             params: { team: { name: '不正なチーム2', category_id: 0, prefecture_id: prefecture.id } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(Team.where(name: '不正なチーム2')).to be_empty
      end
    end

    context 'when both master ids are 0' do
      it 'returns 422' do
        post '/api/v1/teams',
             params: { team: { name: '不正なチーム3', category_id: 0, prefecture_id: 0 } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when prefecture_id is empty string' do
      it 'creates the team treating it as nil' do
        post '/api/v1/teams',
             params: { team: { name: '空文字チーム', category_id: category.id, prefecture_id: '' } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json['prefecture_id']).to be_nil
      end
    end

    context 'when name is blank' do
      it 'returns 422' do
        post '/api/v1/teams',
             params: { team: { name: '', category_id: category.id, prefecture_id: prefecture.id } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
