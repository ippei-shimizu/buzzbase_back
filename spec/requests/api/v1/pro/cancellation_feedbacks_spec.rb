require 'rails_helper'

RSpec.describe 'Api::V1::Pro::CancellationFeedbacks', type: :request do
  let(:user) { create(:user) }

  describe 'POST /api/v1/pro/cancellation_feedbacks' do
    context '未認証のとき' do
      it '401 を返す' do
        post '/api/v1/pro/cancellation_feedbacks', params: { reason: 'expensive' }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'Flipper :cancellation_survey が無効のとき' do
      before { Flipper.disable(:cancellation_survey) }

      it '404 を返し、レコードを作成しない' do
        expect do
          post '/api/v1/pro/cancellation_feedbacks',
               params: { reason: 'expensive' },
               headers: auth_headers_for(user), as: :json
        end.not_to(change(CancellationFeedback, :count))

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'Flipper :cancellation_survey が enabled のとき' do
      before { Flipper.enable_actor(:cancellation_survey, user) }
      after { Flipper.disable(:cancellation_survey) }

      context '正常な reason のみで送信' do
        it '201 + 作成された feedback の id を返す' do
          expect do
            post '/api/v1/pro/cancellation_feedbacks',
                 params: { reason: 'expensive' },
                 headers: auth_headers_for(user), as: :json
          end.to change(CancellationFeedback, :count).by(1)

          expect(response).to have_http_status(:created)
          expect(response.parsed_body['id']).to be_present
        end

        it 'current_user.subscription が自動で紐付く' do
          post '/api/v1/pro/cancellation_feedbacks',
               params: { reason: 'expensive' },
               headers: auth_headers_for(user), as: :json

          feedback = CancellationFeedback.last
          expect(feedback.user).to eq(user)
          expect(feedback.subscription_id).to eq(user.subscription.id)
        end
      end

      context 'reason + note で送信' do
        it '201 を返し note も保存される' do
          post '/api/v1/pro/cancellation_feedbacks',
               params: { reason: 'other', note: 'もっと安ければ続けたかった' },
               headers: auth_headers_for(user), as: :json

          expect(response).to have_http_status(:created)
          expect(CancellationFeedback.last.note).to eq('もっと安ければ続けたかった')
        end
      end

      context 'reason が欠落しているとき' do
        it '422 + error: reason_required を返す' do
          post '/api/v1/pro/cancellation_feedbacks',
               params: { reason: nil },
               headers: auth_headers_for(user), as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body['error']).to eq('reason_required')
        end
      end

      context 'reason が範囲外のとき' do
        it '422 + error: invalid_reason を返す' do
          post '/api/v1/pro/cancellation_feedbacks',
               params: { reason: 'lifetime' },
               headers: auth_headers_for(user), as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body['error']).to eq('invalid_reason')
        end
      end

      context 'note が 1001 文字以上のとき' do
        it '422 + error: note_too_long を返す' do
          post '/api/v1/pro/cancellation_feedbacks',
               params: { reason: 'other', note: 'a' * 1001 },
               headers: auth_headers_for(user), as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body['error']).to eq('note_too_long')
        end
      end

      context '同一ユーザーが 2 回送信したとき' do
        it '両方 201 で受け付ける（重複制約なし）' do
          2.times do
            post '/api/v1/pro/cancellation_feedbacks',
                 params: { reason: 'expensive' },
                 headers: auth_headers_for(user), as: :json
            expect(response).to have_http_status(:created)
          end

          expect(user.cancellation_feedbacks.count).to eq(2)
        end
      end
    end
  end
end
