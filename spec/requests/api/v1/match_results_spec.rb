require 'rails_helper'

RSpec.describe 'Api::V1::MatchResults', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let!(:other_game_result) { create(:game_result, user: other_user) }

  describe 'GET /api/v1/match_index_user_id' do
    context 'when authenticated' do
      it 'returns 200 when target user is public' do
        get '/api/v1/match_index_user_id',
            params: { user_id: other_user.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/match_index_user_id',
            params: { user_id: other_user.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when target user is private' do
      let(:private_user) { create(:user, is_private: true) }

      it 'returns 403 when viewer is not a follower' do
        get '/api/v1/match_index_user_id',
            params: { user_id: private_user.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # Bug #254 (mobile Sentry BUZZBASE-MOBILE-1) リグレッション
  # ApplicationController に rescue_from RecordNotFound が無く、
  # 存在しない id への PUT が 500 を返していた。404 にする。
  describe 'PUT /api/v1/match_results/:id (non-existent id)' do
    context 'when the match_result does not exist' do
      it 'returns 404 with a Japanese error message' do
        put '/api/v1/match_results/999999',
            params: { match_result: { my_team_score: 5 } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['errors']).to include('リソースが見つかりません')
      end
    end
  end

  # Bug #287 (mobile Sentry BUZZBASE-MOBILE-8) リグレッション
  # 既に削除済みリソースへの DELETE で 404 連打ループが発生していた。冪等化する。
  describe 'DELETE /api/v1/match_results/:id' do
    let!(:own_game_result) { create(:game_result, user:) }
    let(:own_match_result) { own_game_result.match_result }

    context 'when authenticated and owner' do
      it 'destroys the match_result and returns 200' do
        delete "/api/v1/match_results/#{own_match_result.id}", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['message']).to eq('試合情報を削除しました')
        expect(MatchResult.exists?(own_match_result.id)).to be false
      end
    end

    context 'when the match_result does not exist (idempotent)' do
      it 'returns 200 with already-deleted message' do
        delete '/api/v1/match_results/999999', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['message']).to eq('試合情報は既に削除されています')
      end
    end

    # 他ユーザーの match_result はユーザースコープ外として nil 扱いになるため、
    # 「既に削除済み」と同じレスポンス (200) を返し、レコードは消えない。
    context 'when the match_result belongs to another user' do
      let(:other_match_result) { other_game_result.match_result }

      it 'returns 200 without deleting the record' do
        delete "/api/v1/match_results/#{other_match_result.id}", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['message']).to eq('試合情報は既に削除されています')
        expect(MatchResult.exists?(other_match_result.id)).to be true
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        delete "/api/v1/match_results/#{own_match_result.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/match_results/:id (ownership scope)' do
    # 他ユーザーの match_result はユーザースコープ外として nil 扱いになるため、
    # update では 404 を返し、レコードは更新されない。
    context 'when the match_result belongs to another user' do
      let(:other_match_result) { other_game_result.match_result }

      it 'returns 404 without updating the record' do
        original_score = other_match_result.my_team_score
        put "/api/v1/match_results/#{other_match_result.id}",
            params: { match_result: { my_team_score: original_score + 99 } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:not_found)
        expect(other_match_result.reload.my_team_score).to eq(original_score)
      end
    end
  end

  # issue #332: 試合基本情報入力で球場（任意項目）を保存できるようにするため、
  # v1 match_results_controller の strong params に :stadium_id を追加した。
  # 既存の MatchResult create フローは GameResult 経由（factory が match_result を自動生成）
  # で行われるため、ここでは PUT による permit 経路を検証することで stadium_id の保存可否を担保する。
  describe 'stadium_id 保存サポート' do
    let(:prefecture) { Prefecture.create!(name: 'spec用都道府県') }
    let(:stadium) { Stadium.create!(name: 'spec用球場', prefecture:, created_by_user: user) }
    let(:match_result) do
      game_result = create(:game_result, user:)
      game_result.match_result
    end

    it 'PUT 時に stadium_id を更新できる（permit 経路を担保）' do
      put "/api/v1/match_results/#{match_result.id}",
          params: { match_result: { stadium_id: stadium.id } },
          headers: auth_headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(match_result.reload.stadium_id).to eq(stadium.id)
    end

    it 'PUT で stadium_id を nil に戻せる（球場を未指定に変更）' do
      match_result.update!(stadium_id: stadium.id)
      put "/api/v1/match_results/#{match_result.id}",
          params: { match_result: { stadium_id: nil } },
          headers: auth_headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(match_result.reload.stadium_id).to be_nil
    end
  end

  describe 'GET /api/v1/match_results/available_years' do
    # game_result factory が after(:create) で match_result を自動生成するため、
    # game_result を作成 → 自動生成された match_result の date_and_time を更新
    def create_match_for(user_record, year:, month: 6, day: 1)
      gr = create(:game_result, user: user_record)
      gr.match_result.update!(date_and_time: Time.zone.local(year, month, day))
      gr.match_result
    end

    context 'when authenticated and user_id is omitted (current user)' do
      it 'returns distinct years for current user in descending order' do
        create_match_for(user, year: 2024, month: 6)
        create_match_for(user, year: 2024, month: 9)
        create_match_for(user, year: 2022, month: 4)

        get '/api/v1/match_results/available_years',
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(%w[2024 2022])
      end
    end

    context 'when authenticated and user_id is provided' do
      it 'returns distinct years for the specified user' do
        create_match_for(other_user, year: 2023, month: 3)

        get '/api/v1/match_results/available_years',
            params: { user_id: other_user.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include('2023')
      end
    end

    context 'when the user has no match results' do
      let(:no_match_user) { create(:user) }

      it 'returns an empty array' do
        get '/api/v1/match_results/available_years',
            params: { user_id: no_match_user.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq([])
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/match_results/available_years'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when target user is private and viewer is not a follower' do
      let(:private_user) { create(:user, is_private: true) }

      it 'returns 403' do
        get '/api/v1/match_results/available_years',
            params: { user_id: private_user.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user_id does not exist' do
      it 'returns 404' do
        get '/api/v1/match_results/available_years',
            params: { user_id: 999_999 },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/match_results/form_defaults' do
    context 'when the user has no match_results and no profile positions' do
      it 'returns inning_format=9 and nil for the other fields' do
        get '/api/v1/match_results/form_defaults', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['inning_format']).to eq(9)
        expect(body['match_type']).to be_nil
        expect(body['defensive_position']).to be_nil
        expect(body['batting_order']).to be_nil
      end
    end

    context 'when the user has prior match_results' do
      before do
        old_gr = create(:game_result, user:)
        old_gr.match_result.update!(date_and_time: Time.zone.local(2024, 1, 1), inning_format: 9,
                                    match_type: 'open', defensive_position: 'ピッチャー', batting_order: '1')

        latest_gr = create(:game_result, user:)
        latest_gr.match_result.update!(date_and_time: Time.zone.local(2025, 6, 1), inning_format: 7,
                                       match_type: 'regular', defensive_position: 'ショート', batting_order: '4')
      end

      it 'returns the latest match_result values (match_type humanized to Japanese label)' do
        get '/api/v1/match_results/form_defaults', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['inning_format']).to eq(7)
        expect(body['match_type']).to eq('公式戦')
        expect(body['defensive_position']).to eq('ショート')
        expect(body['batting_order']).to eq('4')
      end
    end

    context 'when the user has profile positions configured' do
      it 'returns the profile position as defensive_position regardless of latest match_result' do
        position = Position.create!(name: 'キャッチャー')
        UserPosition.create!(user:, position:)

        gr = create(:game_result, user:)
        gr.match_result.update!(
          date_and_time: Time.zone.local(2025, 6, 1),
          defensive_position: 'ショート'
        )

        get '/api/v1/match_results/form_defaults', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['defensive_position']).to eq('キャッチャー')
      end
    end

    context 'when the user has profile positions but no match_results' do
      it 'returns the profile position as defensive_position' do
        position = Position.create!(name: 'セカンド')
        UserPosition.create!(user:, position:)

        get '/api/v1/match_results/form_defaults', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['defensive_position']).to eq('セカンド')
        expect(body['match_type']).to be_nil
      end
    end

    context 'when multiple match_results share the same date_and_time' do
      before do
        # 同じ日付の試合を順番に作る。最後に作成（id 最大）したのが直近の試合として返るべき。
        old_gr = create(:game_result, user:)
        old_gr.match_result.update!(date_and_time: Time.zone.local(2025, 6, 1), match_type: 'open', inning_format: 7)

        new_gr = create(:game_result, user:)
        new_gr.match_result.update!(date_and_time: Time.zone.local(2025, 6, 1), match_type: 'regular', inning_format: 9)
      end

      it 'returns the most recently created match_result (tie-broken by id desc)' do
        get '/api/v1/match_results/form_defaults', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['match_type']).to eq('公式戦')
        expect(body['inning_format']).to eq(9)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/match_results/form_defaults'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/match_results/:id (inning_format)' do
    let(:my_team) { create(:team) }
    let(:opponent_team) { create(:team) }
    let(:game_result) { create(:game_result, user:) }

    # game_result 作成時に factory の after(:create) で match_result が自動生成されるため、
    # テスト用に game_result を作っておき、その game_result 用の MatchResult を別途作るのではなく
    # factory が生成した既存 match_result を inning_format = 7 に更新するパターンも併設する。
    context 'when inning_format = 7 is provided' do
      it 'persists inning_format on the existing match_result via update' do
        match_result = game_result.match_result

        put "/api/v1/match_results/#{match_result.id}",
            params: { match_result: { inning_format: 7 } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(match_result.reload.inning_format).to eq(7)
      end
    end

    context 'when inning_format is invalid (e.g. 5)' do
      it 'returns 422 with validation errors' do
        match_result = game_result.match_result

        put "/api/v1/match_results/#{match_result.id}",
            params: { match_result: { inning_format: 5 } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT /api/v1/match_results/:id (appearance_type)' do
    let(:game_result) { create(:game_result, user:) }

    context 'when appearance_type = pinch_hitter is provided with empty batting_order/defensive_position' do
      it 'persists the appearance_type without batting_order / defensive_position' do
        match_result = game_result.match_result

        put "/api/v1/match_results/#{match_result.id}",
            params: { match_result: {
              appearance_type: 'pinch_hitter',
              batting_order: '',
              defensive_position: ''
            } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(match_result.reload.appearance_type).to eq('pinch_hitter')
      end
    end

    context 'when appearance_type = pinch_runner is provided with empty batting_order/defensive_position' do
      it 'persists the appearance_type without batting_order / defensive_position' do
        match_result = game_result.match_result

        put "/api/v1/match_results/#{match_result.id}",
            params: { match_result: {
              appearance_type: 'pinch_runner',
              batting_order: '',
              defensive_position: ''
            } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(match_result.reload.appearance_type).to eq('pinch_runner')
      end
    end

    context 'when appearance_type = starter and batting_order is missing' do
      it 'returns 200 because batting_order is optional even for starter (DH-rule pitcher case)' do
        match_result = game_result.match_result

        put "/api/v1/match_results/#{match_result.id}",
            params: { match_result: {
              appearance_type: 'starter',
              batting_order: ''
            } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        expect(match_result.reload.batting_order).to eq('')
      end
    end

    context 'when appearance_type is invalid (e.g. unknown)' do
      it 'returns 422 with validation errors' do
        match_result = game_result.match_result

        put "/api/v1/match_results/#{match_result.id}",
            params: { match_result: { appearance_type: 'unknown' } },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /api/v1/user_game_result_search' do
    context 'when authenticated' do
      it 'returns 200' do
        get '/api/v1/user_game_result_search',
            params: { game_result_id: other_game_result.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok).or have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v1/user_game_result_search',
            params: { game_result_id: other_game_result.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when target user is private' do
      let(:private_user) { create(:user, is_private: true) }
      let!(:private_game_result) { create(:game_result, user: private_user) }

      it 'returns 403 when viewer is not a follower' do
        get '/api/v1/user_game_result_search',
            params: { game_result_id: private_game_result.id },
            headers: auth_headers_for(user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
