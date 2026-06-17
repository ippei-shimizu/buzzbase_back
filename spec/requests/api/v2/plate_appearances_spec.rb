require 'rails_helper'

RSpec.describe 'Api::V2::PlateAppearances', type: :request do
  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }

  describe 'POST /api/v2/plate_appearances' do
    let(:base_params) do
      {
        plate_appearance: {
          game_result_id: game_result.id,
          batter_box_number: 1,
          plate_result_id: 7,
          hit_direction_id: 10,
          hit_location_x: 0.5,
          hit_location_y: 0.3,
          rbi: 1,
          run_scored: 0
        }
      }
    end

    context 'when authenticated' do
      it '201 で作成され、batting_result がサーバー生成された値で返る' do
        post '/api/v2/plate_appearances', params: base_params, headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json['batting_result']).to eq('中安')
        expect(json['is_new_format']).to be(true)
      end

      it '作成された打席は is_new_format=true で保存される' do
        post '/api/v2/plate_appearances', params: base_params, headers: auth_headers_for(user)
        created = PlateAppearance.find(response.parsed_body['id'])
        expect(created.is_new_format).to be(true)
      end

      it 'batting_average が再集計されて作成される' do
        expect do
          post '/api/v2/plate_appearances', params: base_params, headers: auth_headers_for(user)
        end.to change { BattingAverage.where(game_result_id: game_result.id).count }.from(0).to(1)

        batting_average = BattingAverage.find_by(game_result_id: game_result.id)
        expect(batting_average.hit).to eq(1)
        expect(batting_average.at_bats).to eq(1)
      end

      it '他ユーザーの game_result_id を指定すると 404（IDOR防止）' do
        other_user = create(:user)
        other_game = create(:game_result, user: other_user)
        bad_params = { plate_appearance: { game_result_id: other_game.id, batter_box_number: 1 } }
        post '/api/v2/plate_appearances', params: bad_params, headers: auth_headers_for(user)
        expect(response).to have_http_status(:not_found)
      end

      it '他ユーザーが作成した pitcher_id を指定すると 422（IDOR防止）' do
        other_user = create(:user)
        other_pitcher = Pitcher.create!(name: '他人の投手', throw_hand: :right, created_by_user: other_user)
        bad_params = base_params.deep_merge(plate_appearance: { pitcher_id: other_pitcher.id })

        post '/api/v2/plate_appearances', params: bad_params, headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to include('指定された投手は存在しません')
      end

      it '自分が作成した pitcher_id を指定すると作成できる' do
        own_pitcher = Pitcher.create!(name: '自分の投手', throw_hand: :left, created_by_user: user)
        good_params = base_params.deep_merge(plate_appearance: { pitcher_id: own_pitcher.id })

        post '/api/v2/plate_appearances', params: good_params, headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
        expect(PlateAppearance.find(response.parsed_body['id']).pitcher_id).to eq(own_pitcher.id)
      end

      it '三振 (plate_result_id=13) + swing_type=swinging で 201 と swing_type 保存' do
        strikeout_params = {
          plate_appearance: {
            game_result_id: game_result.id,
            batter_box_number: 2,
            plate_result_id: 13,
            swing_type: 'swinging'
          }
        }
        post '/api/v2/plate_appearances', params: strikeout_params, headers: auth_headers_for(user)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body['swing_type']).to eq('swinging')
        expect(PlateAppearance.find(response.parsed_body['id']).swing_type_swinging?).to be(true)
      end

      it '三振以外 (例: 単打 id=7) に swing_type を指定すると 422' do
        bad_params = base_params.deep_merge(plate_appearance: { swing_type: 'swinging' })

        post '/api/v2/plate_appearances', params: bad_params, headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors'].join).to include('三振')
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        post '/api/v2/plate_appearances', params: base_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v2/plate_appearances/:id' do
    let!(:plate_appearance) do
      create(:plate_appearance, game_result:, user:, plate_result_id: 1,
                                hit_direction_id: 1, is_new_format: true, batter_box_number: 1)
    end

    context 'when authenticated' do
      it '200 で更新され、batting_result が再生成される' do
        patch "/api/v2/plate_appearances/#{plate_appearance.id}",
              params: { plate_appearance: { plate_result_id: 7, hit_direction_id: 10 } },
              headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['batting_result']).to eq('中安')
      end

      it '他ユーザーの打席は更新できない (404)' do
        other_user = create(:user)
        patch "/api/v2/plate_appearances/#{plate_appearance.id}",
              params: { plate_appearance: { plate_result_id: 7 } },
              headers: auth_headers_for(other_user)
        expect(response).to have_http_status(:not_found)
      end

      it '他ユーザーが作成した pitcher_id を指定すると 422（IDOR防止）' do
        other_user = create(:user)
        other_pitcher = Pitcher.create!(name: '他人の投手', throw_hand: :right, created_by_user: other_user)

        patch "/api/v2/plate_appearances/#{plate_appearance.id}",
              params: { plate_appearance: { pitcher_id: other_pitcher.id } },
              headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to include('指定された投手は存在しません')
        expect(plate_appearance.reload.pitcher_id).to be_nil
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        patch "/api/v2/plate_appearances/#{plate_appearance.id}",
              params: { plate_appearance: { plate_result_id: 7 } }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v2/plate_appearances/:id' do
    let!(:plate_appearance) do
      create(:plate_appearance, game_result:, user:, plate_result_id: 7,
                                hit_direction_id: 10, is_new_format: true, batter_box_number: 1)
    end

    context 'when authenticated' do
      it '削除して batting_average を再計算する' do
        delete "/api/v2/plate_appearances/#{plate_appearance.id}", headers: auth_headers_for(user)
        expect(response).to have_http_status(:ok)
        expect(PlateAppearance.where(id: plate_appearance.id)).not_to exist
      end

      it '新仕様試合の最後の打席を削除すると孤立する batting_average も削除される' do
        create(:batting_average, game_result:, user:, at_bats: 1, hit: 1)
        delete "/api/v2/plate_appearances/#{plate_appearance.id}", headers: auth_headers_for(user)
        expect(BattingAverage.where(game_result_id: game_result.id)).not_to exist
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        delete "/api/v2/plate_appearances/#{plate_appearance.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v2/plate_appearances/by_game/:game_result_id' do
    before do
      create(:plate_appearance, game_result:, user:, plate_result_id: 7,
                                hit_direction_id: 10, is_new_format: true, batter_box_number: 1)
      create(:plate_appearance, game_result:, user:, plate_result_id: 1,
                                hit_direction_id: 1, is_new_format: true, batter_box_number: 2)
    end

    context 'when authenticated' do
      it '試合の全打席を batter_box_number 昇順で返す' do
        get "/api/v2/plate_appearances/by_game/#{game_result.id}", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        items = response.parsed_body['plate_appearances']
        expect(items.size).to eq(2)
        expect(items.pluck('batter_box_number')).to eq([1, 2])
      end

      it '非公開ユーザーの試合は 403' do
        private_user = create(:user, is_private: true)
        private_game = create(:game_result, user: private_user)
        get "/api/v2/plate_appearances/by_game/#{private_game.id}", headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get "/api/v2/plate_appearances/by_game/#{game_result.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
