# frozen_string_literal: true

require 'rails_helper'

# v1 API レスポンス形のスナップショット（後方互換の砦）。
# 旧モバイルクライアントが依存する読み取り系エンドポイントの「キー・型」を固定し、
# v2 リファクタの副作用で v1 の形が壊れたら CI で必ず落とす。
#
# カバレッジ: 旧クライアントの主要導線（試合・打撃成績・投手成績・ユーザー）。
# 残りの v1 エンドポイントは同じ仕組み（expect_v1_schema）で順次追加していく。
RSpec.describe 'v1 API レスポンス形スナップショット', type: :request do
  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }
  let(:match_result) { game_result.match_result }

  before do
    match_result
    create(:batting_average, game_result:, user:)
    create(:pitching_result, game_result:, user:)
  end

  it 'GET /api/v1/match_results（index）' do
    get '/api/v1/match_results', headers: auth_headers_for(user)
    expect(response).to have_http_status(:ok)
    expect_v1_schema('match_results_index', response.parsed_body)
  end

  it 'GET /api/v1/match_results/:id（show）' do
    get "/api/v1/match_results/#{match_result.id}", headers: auth_headers_for(user)
    expect(response).to have_http_status(:ok)
    expect_v1_schema('match_results_show', response.parsed_body)
  end

  it 'GET /api/v1/batting_averages/personal_batting_average' do
    get '/api/v1/batting_averages/personal_batting_average',
        params: { user_id: user.id, year: '通算' }, headers: auth_headers_for(user)
    expect(response).to have_http_status(:ok)
    expect_v1_schema('personal_batting_average', response.parsed_body)
  end

  it 'GET /api/v1/batting_averages/personal_batting_stats' do
    get '/api/v1/batting_averages/personal_batting_stats',
        params: { user_id: user.id, year: '通算' }, headers: auth_headers_for(user)
    expect(response).to have_http_status(:ok)
    expect_v1_schema('personal_batting_stats', response.parsed_body)
  end

  it 'GET /api/v1/pitching_results/personal_pitching_stats' do
    get '/api/v1/pitching_results/personal_pitching_stats',
        params: { user_id: user.id, year: '通算' }, headers: auth_headers_for(user)
    expect(response).to have_http_status(:ok)
    expect_v1_schema('personal_pitching_stats', response.parsed_body)
  end

  it 'GET /api/v1/users/:id（show）' do
    get "/api/v1/users/#{user.id}", headers: auth_headers_for(user)
    expect(response).to have_http_status(:ok)
    expect_v1_schema('users_show', response.parsed_body)
  end
end
