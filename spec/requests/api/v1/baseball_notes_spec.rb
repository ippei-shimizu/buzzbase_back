require 'rails_helper'

RSpec.describe 'Api::V1::BaseballNotes', type: :request do
  let(:user) { create(:user) }

  describe 'POST /api/v1/baseball_notes' do
    let(:params) { { baseball_note: { title: 'ノート', date: Date.current, memo: '素振り' } } }

    context 'when authenticated' do
      it 'creates a baseball note' do
        post '/api/v1/baseball_notes', params:, headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
        expect(user.baseball_notes.count).to eq(1)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        post('/api/v1/baseball_notes', params:)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
