# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V2::Stats', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }

  before do
    gr = create(:game_result, user:)
    gr.match_result.update!(
      date_and_time: Time.zone.local(2024, 7, 10),
      match_type: '公式戦',
      my_team_score: 5,
      opponent_team_score: 3
    )
    create(:batting_average, game_result: gr, user:,
                             hit: 2, at_bats: 4, times_at_bat: 5,
                             home_run: 1, runs_batted_in: 3, total_bases: 5)
    create(:pitching_result, game_result: gr, user:,
                             win: 1, innings_pitched: 7.0, earned_run: 2,
                             strikeouts: 6, base_on_balls: 2, hits_allowed: 5)
    create(:plate_appearance, game_result: gr, user:,
                              hit_direction_id: 8, plate_result_id: 7,
                              batter_box_number: 1)
  end

  describe 'GET /api/v2/stats/hit_directions' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/hit_directions'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with directions and home_runs' do
      get('/api/v2/stats/hit_directions', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['directions']).to be_an(Array)
      expect(json['home_runs']).to be_an(Array)
      expect(json['directions'].first).to include('id', 'label', 'count', 'top_category')
    end
  end

  describe 'GET /api/v2/stats/plate_appearance_breakdown' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/plate_appearance_breakdown'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with breakdown array' do
      get('/api/v2/stats/plate_appearance_breakdown', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['breakdown']).to be_an(Array)
    end
  end

  describe 'GET /api/v2/stats/batting' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/batting'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with rows array' do
      get('/api/v2/stats/batting', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['rows']).to be_an(Array)
    end
  end

  describe 'GET /api/v2/stats/pitching' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/pitching'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with rows array' do
      get('/api/v2/stats/pitching', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['rows']).to be_an(Array)
    end
  end

  describe 'GET /api/v2/stats/era_trend' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/era_trend'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with trend array' do
      get('/api/v2/stats/era_trend', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['trend']).to be_an(Array)
      expect(json['trend'].first).to include('month', 'era') if json['trend'].any?
    end
  end

  describe 'GET /api/v2/stats/game_summary' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/game_summary'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with summary structure' do
      get('/api/v2/stats/game_summary', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to include('win_loss', 'scoring', 'recent_form', 'monthly_games', 'opponent_records')
      expect(json['win_loss']).to include('wins', 'losses', 'draws', 'total', 'win_rate')
      expect(json['scoring']).to include('runs_for', 'runs_against', 'run_differential')
      expect(json['recent_form']).to be_an(Array)
      expect(json['monthly_games']).to be_an(Array)
      expect(json['opponent_records']).to be_an(Array)
    end
  end
end
