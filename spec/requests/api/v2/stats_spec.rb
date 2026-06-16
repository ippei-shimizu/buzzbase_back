# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V2::Stats', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }

  before do
    gr = create(:game_result, user:)
    gr.match_result.update!(
      date_and_time: Time.zone.local(2024, 7, 10),
      match_type: 'regular',
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

    it 'includes match_type in each recent_form item' do
      get('/api/v2/stats/game_summary', headers:)

      json = response.parsed_body
      expect(json['recent_form'].first).to include(
        'game_result_id', 'date', 'match_type', 'opponent', 'result', 'my_score', 'opponent_score'
      )
      expect(json['recent_form'].first['match_type']).to eq('regular')
    end
  end

  describe 'GET /api/v2/stats/headline_stats' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/headline_stats'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with the 7 headline indicators and at_bats' do
      get('/api/v2/stats/headline_stats', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to include(
        'batting_average', 'hit', 'home_run', 'runs_batted_in',
        'on_base_percentage', 'slugging_percentage', 'ops', 'at_bats'
      )
    end
  end

  describe 'GET /api/v2/stats/runners_situation' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/runners_situation'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with scoring position aggregation' do
      get('/api/v2/stats/runners_situation', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to include(
        'batting_average', 'at_bats', 'hits',
        'two_base_hit', 'three_base_hit', 'home_run'
      )
    end
  end

  describe 'GET /api/v2/stats/hit_locations' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/hit_locations'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with points array' do
      get('/api/v2/stats/hit_locations', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to include('points')
      expect(json['points']).to be_an(Array)
    end
  end

  describe 'GET /api/v2/stats/out_type_breakdown' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/out_type_breakdown'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with breakdown of out_type enum categories' do
      get('/api/v2/stats/out_type_breakdown', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to include('breakdown', 'total')
      expect(json['breakdown']).to be_an(Array)
      expect(json['breakdown'].first).to include('category', 'count', 'percentage')
    end
  end

  describe 'GET /api/v2/stats/hit_directions (拡張済みフィールド)' do
    it 'returns directions with at_bats / hits / total_bases / two_base_hit / three_base_hit / home_run' do
      get('/api/v2/stats/hit_directions', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['directions'].first).to include(
        'id', 'label', 'count', 'top_category',
        'at_bats', 'hits', 'two_base_hit', 'three_base_hit', 'home_run', 'total_bases'
      )
    end
  end

  describe 'GET /api/v2/stats/count_situations' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/count_situations'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with first_pitch / favorable_count / pinch_count + total_target_pa' do
      get('/api/v2/stats/count_situations', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to include('first_pitch', 'favorable_count', 'pinch_count', 'total_target_pa')
      %w[first_pitch favorable_count pinch_count].each do |key|
        expect(json[key]).to include('at_bats', 'hits', 'batting_average')
      end
    end
  end

  describe 'GET /api/v2/stats/contact_qualities' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/contact_qualities'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with breakdown of all 5 master categories' do
      get('/api/v2/stats/contact_qualities', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to include('breakdown', 'total')
      expect(json['breakdown']).to be_an(Array)
      expect(json['breakdown'].first).to include('id', 'label', 'count', 'percentage')
    end
  end

  describe 'GET /api/v2/stats/pitch_types' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/pitch_types'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with rows for all 10 master pitch types + total_target_pa' do
      get('/api/v2/stats/pitch_types', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to include('rows', 'total_target_pa')
      expect(json['rows']).to be_an(Array)
      expect(json['rows'].first).to include(
        'id', 'label', 'at_bats', 'hits', 'total_bases',
        'batting_average', 'slugging_percentage'
      )
    end
  end

  describe 'GET /api/v2/stats/pitcher_faceoffs' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/pitcher_faceoffs'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with rows + total_target_pa + min_plate_appearances' do
      get('/api/v2/stats/pitcher_faceoffs', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to include('rows', 'total_target_pa', 'min_plate_appearances')
      expect(json['rows']).to be_an(Array)
      expect(json['min_plate_appearances']).to eq(3)
    end
  end

  describe 'GET /api/v2/stats/batting_trend' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/batting_trend'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with granularity (default game) + points array' do
      get('/api/v2/stats/batting_trend', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to include('granularity', 'points')
      expect(json['granularity']).to eq('game')
      expect(json['points']).to be_an(Array)
    end

    it 'returns granularity=month when granularity=month is requested' do
      get('/api/v2/stats/batting_trend', headers:, params: { granularity: 'month' })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['granularity']).to eq('month')
    end
  end

  describe 'GET /api/v2/stats/additional_stats' do
    it 'returns 401 when not authenticated' do
      get '/api/v2/stats/additional_stats'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 200 with 16 additional stat indicators' do
      get('/api/v2/stats/additional_stats', headers:)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to include(
        'games', 'plate_appearances', 'two_base_hit', 'three_base_hit',
        'total_bases', 'run', 'strike_out', 'base_on_balls', 'hit_by_pitch',
        'sacrifice_hit', 'sacrifice_fly', 'stealing_base', 'caught_stealing',
        'iso', 'isod', 'bb_per_k'
      )
    end
  end

  describe '非公開アカウントの可視性ガード' do
    let(:private_user) { create(:user, is_private: true) }

    context 'when viewer is not a follower' do
      it 'returns 403 for headline_stats' do
        get '/api/v2/stats/headline_stats',
            params: { user_id: private_user.id },
            headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns 403 for batting table' do
        get '/api/v2/stats/batting',
            params: { user_id: private_user.id },
            headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns 403 for era_trend' do
        get '/api/v2/stats/era_trend',
            params: { user_id: private_user.id },
            headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when viewer is an accepted follower' do
      before do
        Relationship.create!(follower: user, followed: private_user, status: :accepted)
      end

      it 'returns 200 for headline_stats' do
        get '/api/v2/stats/headline_stats',
            params: { user_id: private_user.id },
            headers: auth_headers_for(user)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when target is self (private)' do
      let(:user) { create(:user, is_private: true) }

      it 'returns 200 for headline_stats' do
        get '/api/v2/stats/headline_stats',
            params: { user_id: user.id },
            headers: auth_headers_for(user)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
