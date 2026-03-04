require 'rails_helper'

RSpec.describe 'Api::V2::Dashboards', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v2/dashboard' do
    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/v2/dashboard'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated with no data' do
      it 'returns 200 with empty dashboard data' do
        get '/api/v2/dashboard', headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['recent_game_results']).to eq([])
        expect(json['batting_stats']).to eq({ 'aggregate' => nil, 'calculated' => nil })
        expect(json['pitching_stats']).to eq({ 'aggregate' => nil, 'calculated' => nil })
        expect(json['group_rankings']).to eq([])
        expect(json['available_years']).to eq([])
      end
    end

    context 'when user has game results with batting data' do
      let!(:game_result) do
        gr = create(:game_result, user:)
        gr.match_result.update!(date_and_time: Time.zone.local(2024, 7, 10), match_type: 'regular')
        create(:batting_average, game_result: gr, user:,
                                 hit: 2, at_bats: 4, times_at_bat: 5, home_run: 1, runs_batted_in: 3,
                                 total_bases: 5, two_base_hit: 0, three_base_hit: 0,
                                 base_on_balls: 1, strike_out: 1)
        gr
      end

      it 'returns recent_game_results with batting data' do
        get '/api/v2/dashboard', headers: auth_headers_for(user)

        json = response.parsed_body
        recent = json['recent_game_results']
        expect(recent.size).to eq(1)
        expect(recent.first['id']).to eq(game_result.id)
        expect(recent.first['batting_average']).to include('hit' => 2, 'at_bats' => 4, 'home_run' => 1)
      end

      it 'returns batting_stats with aggregate and calculated values' do
        get '/api/v2/dashboard', headers: auth_headers_for(user)

        json = response.parsed_body
        batting = json['batting_stats']
        expect(batting['aggregate']).to include('hit' => 2, 'at_bats' => 4, 'home_run' => 1)
        expect(batting['calculated']).to include('batting_average', 'on_base_percentage', 'slugging_percentage', 'ops')
        expect(batting['calculated']['batting_average']).to be_a(Numeric)
      end

      it 'returns available_years containing the game year' do
        get '/api/v2/dashboard', headers: auth_headers_for(user)

        json = response.parsed_body
        expect(json['available_years']).to include(2024)
      end
    end

    context 'when user has pitching data' do
      let!(:game_result) do
        gr = create(:game_result, user:)
        gr.match_result.update!(date_and_time: Time.zone.local(2024, 8, 15))
        create(:pitching_result, game_result: gr, user:,
                                 win: 1, innings_pitched: 7.0, earned_run: 2, strikeouts: 8,
                                 base_on_balls: 1, hits_allowed: 4)
        gr
      end

      it 'returns pitching_stats with aggregate and calculated values' do
        get '/api/v2/dashboard', headers: auth_headers_for(user)

        json = response.parsed_body
        pitching = json['pitching_stats']
        expect(pitching['aggregate']).to include('win' => 1, 'strikeouts' => 8)
        expect(pitching['aggregate']['innings_pitched']).to eq(7.0)
        expect(pitching['calculated']).to include('era', 'whip', 'k_per_nine', 'win_percentage')
        expect(pitching['calculated']['era']).to be_a(Numeric)
      end

      it 'returns recent_game_results with pitching data' do
        get '/api/v2/dashboard', headers: auth_headers_for(user)

        json = response.parsed_body
        recent = json['recent_game_results']
        expect(recent.first['pitching_result']).to include('innings_pitched' => 7.0, 'strikeouts' => 8)
      end
    end

    context 'when recent_game_results are limited to 3' do
      before do
        4.times do |i|
          gr = create(:game_result, user:)
          gr.match_result.update!(date_and_time: Time.zone.local(2024, 1 + i, 10))
          create(:batting_average, game_result: gr, user:)
        end
      end

      it 'returns at most 3 recent game results' do
        get '/api/v2/dashboard', headers: auth_headers_for(user)

        json = response.parsed_body
        expect(json['recent_game_results'].size).to eq(3)
      end
    end

    context 'with year and match_type filter params' do
      let!(:game_2024_regular) do
        gr = create(:game_result, user:)
        gr.match_result.update!(date_and_time: Time.zone.local(2024, 5, 10), match_type: 'regular')
        create(:batting_average, game_result: gr, user:, hit: 3, at_bats: 4, times_at_bat: 4)
        gr
      end

      let!(:game_2024_open) do
        gr = create(:game_result, user:)
        gr.match_result.update!(date_and_time: Time.zone.local(2024, 6, 20), match_type: 'open')
        create(:batting_average, game_result: gr, user:, hit: 1, at_bats: 5, times_at_bat: 5)
        gr
      end

      let!(:game_2023_regular) do
        gr = create(:game_result, user:)
        gr.match_result.update!(date_and_time: Time.zone.local(2023, 9, 1), match_type: 'regular')
        create(:batting_average, game_result: gr, user:, hit: 2, at_bats: 4, times_at_bat: 4)
        gr
      end

      it 'filters batting_stats by year' do
        get '/api/v2/dashboard', params: { year: '2024' }, headers: auth_headers_for(user)

        json = response.parsed_body
        batting = json['batting_stats']
        # 2024年の試合は2試合: hit=3+1=4, at_bats=4+5=9
        expect(batting['aggregate']['hit']).to eq(4)
        expect(batting['aggregate']['at_bats']).to eq(9)
      end

      it 'filters batting_stats by match_type' do
        get '/api/v2/dashboard', params: { match_type: 'regular' }, headers: auth_headers_for(user)

        json = response.parsed_body
        batting = json['batting_stats']
        # regular試合は2試合: hit=3+2=5, at_bats=4+4=8
        expect(batting['aggregate']['hit']).to eq(5)
        expect(batting['aggregate']['at_bats']).to eq(8)
      end

      it 'filters batting_stats by both year and match_type' do
        get '/api/v2/dashboard', params: { year: '2024', match_type: 'regular' }, headers: auth_headers_for(user)

        json = response.parsed_body
        batting = json['batting_stats']
        # 2024年のregular試合は1試合: hit=3, at_bats=4
        expect(batting['aggregate']['hit']).to eq(3)
        expect(batting['aggregate']['at_bats']).to eq(4)
      end

      it 'returns all stats when year is "通算" and match_type is "全て"' do
        get '/api/v2/dashboard', params: { year: '通算', match_type: '全て' }, headers: auth_headers_for(user)

        json = response.parsed_body
        batting = json['batting_stats']
        # 全試合: hit=3+1+2=6, at_bats=4+5+4=13
        expect(batting['aggregate']['hit']).to eq(6)
        expect(batting['aggregate']['at_bats']).to eq(13)
      end
    end

    context 'when user belongs to a group' do
      let(:group) { Group.create!(name: 'テストグループ') }
      let(:teammate) { create(:user) }

      before do
        GroupInvitation.create!(user:, group:, state: 'accepted', sent_at: Time.current)
        GroupInvitation.create!(user: teammate, group:, state: 'accepted', sent_at: Time.current)

        # ユーザーに打撃成績を追加
        gr = create(:game_result, user:)
        create(:batting_average, game_result: gr, user:, hit: 3, at_bats: 10, times_at_bat: 10)

        # チームメイトに打撃成績を追加
        gr2 = create(:game_result, user: teammate)
        create(:batting_average, game_result: gr2, user: teammate, hit: 4, at_bats: 10, times_at_bat: 10)
      end

      it 'returns group_rankings with group info and rankings' do
        get '/api/v2/dashboard', headers: auth_headers_for(user)

        json = response.parsed_body
        rankings = json['group_rankings']
        expect(rankings.size).to eq(1)
        expect(rankings.first['group_name']).to eq('テストグループ')
        expect(rankings.first['total_members']).to eq(2)
        expect(rankings.first['batting_rankings']).to be_an(Array)
        expect(rankings.first['pitching_rankings']).to be_an(Array)
      end

      it 'calculates current_rank correctly for batting stats' do
        get '/api/v2/dashboard', headers: auth_headers_for(user)

        json = response.parsed_body
        batting_rankings = json['group_rankings'].first['batting_rankings']
        hit_ranking = batting_rankings.find { |r| r['stat_type'] == 'hit' }
        # teammate has 4 hits > user has 3 hits, so user is rank 2
        expect(hit_ranking['current_rank']).to eq(2)
      end

      it 'includes change from previous snapshot when available' do
        # 前回のスナップショットを作成（ユーザーが1位だった）
        GroupRankingSnapshot.create!(
          group:, user:, stat_type: 'hit',
          rank: 1, value: 5, snapshot_date: 1.week.ago.to_date
        )

        get '/api/v2/dashboard', headers: auth_headers_for(user)

        json = response.parsed_body
        batting_rankings = json['group_rankings'].first['batting_rankings']
        hit_ranking = batting_rankings.find { |r| r['stat_type'] == 'hit' }
        # previous_rank=1, current_rank=2 => change = 1 - 2 = -1
        expect(hit_ranking['previous_rank']).to eq(1)
        expect(hit_ranking['change']).to eq(-1)
      end
    end
  end
end
