require 'rails_helper'

RSpec.describe 'Api::V1::Awards', type: :request do
  let(:user) { create(:user) }

  describe 'POST /api/v1/users/:user_id/awards' do
    context 'when title is blank' do
      it 'returns 422' do
        post "/api/v1/users/#{user.id}/awards",
             params: { award: { title: '' } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json['errors']).to include('タイトルを入力してください')
      end
    end

    context 'when title is nil' do
      it 'returns 422' do
        post "/api/v1/users/#{user.id}/awards",
             params: { award: { title: nil } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when title is valid' do
      it 'creates the award and returns 201' do
        post "/api/v1/users/#{user.id}/awards",
             params: { award: { title: 'MVP' } },
             headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json['title']).to eq('MVP')
      end
    end
  end

  describe 'DELETE /api/v1/users/:user_id/awards/:id' do
    context 'when user_award does not exist' do
      it 'returns 404' do
        delete "/api/v1/users/#{user.id}/awards/999999",
               headers: auth_headers_for(user)

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json['error']).to eq('受賞タイトルが見つかりません')
      end
    end

    context 'when user_award exists' do
      let(:award) { Award.create!(title: 'MVP') }

      before do
        user.awards << award
      end

      it 'destroys the user_award and orphaned award, returns 200' do
        delete "/api/v1/users/#{user.id}/awards/#{award.id}",
               headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(UserAward.find_by(user_id: user.id, award_id: award.id)).to be_nil
        expect(Award.find_by(id: award.id)).to be_nil
      end

      context 'when another user also has the same award' do
        let(:other_user) { create(:user) }

        before do
          other_user.awards << award
        end

        it 'destroys only the user_award but keeps the shared award' do
          delete "/api/v1/users/#{user.id}/awards/#{award.id}",
                 headers: auth_headers_for(user)

          expect(response).to have_http_status(:ok)
          expect(UserAward.find_by(user_id: user.id, award_id: award.id)).to be_nil
          expect(Award.find_by(id: award.id)).to be_present
          expect(other_user.awards.reload).to include(award)
        end
      end
    end
  end
end
