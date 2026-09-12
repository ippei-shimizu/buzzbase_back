require 'rails_helper'

# v2 API 経由の打席操作が、既存ユーザーデータを破壊しないことを担保する。
#
# 検証ポイント:
# - 旧仕様試合の batting_average レコードに v2 が触らない
# - v2 で新仕様試合を作成しても、別試合の batting_average に影響しない
# - ユーザー通算打率が新旧合算で一貫している（BattingAverage.aggregate_for_user の SUM）
RSpec.describe 'v2 経由打席操作の既存データ保全', type: :request do
  let(:user) { create(:user) }

  describe '旧仕様試合（is_new_format=false の打席のみ）の batting_average を v2 が改変しない' do
    let(:old_format_game) { create(:game_result, user:) }
    let!(:old_batting_average) do
      # フロントから直接保存された既存値（サーバー計算とは異なる値を意図的に設定）
      create(:batting_average, game_result: old_format_game, user:,
                               at_bats: 99, hit: 88, total_bases: 77)
    end

    before do
      create(:plate_appearance, game_result: old_format_game, user:, plate_result_id: 7,
                                hit_direction_id: 10, is_new_format: false, batting_result: '中安')
    end

    it '別試合に v2 で新仕様の打席を作成しても、旧仕様試合の batting_average は不変' do
      new_format_game = create(:game_result, user:)

      post '/api/v2/plate_appearances',
           params: {
             plate_appearance: {
               game_result_id: new_format_game.id, batter_box_number: 1,
               plate_result_id: 7, hit_direction_id: 10
             }
           },
           headers: auth_headers_for(user)

      expect(response).to have_http_status(:created)

      old_batting_average.reload
      expect(old_batting_average.at_bats).to eq(99)
      expect(old_batting_average.hit).to eq(88)
      expect(old_batting_average.total_bases).to eq(77)
    end
  end

  describe 'v2 で同じ game_result に複数打席を追加しても、別 game_result の batting_average に影響しない' do
    let(:target_game) { create(:game_result, user:) }
    let(:other_game) { create(:game_result, user:) }
    let!(:other_batting_average) do
      create(:batting_average, game_result: other_game, user:, at_bats: 50, hit: 25)
    end

    it '他試合の batting_average は不変' do
      post '/api/v2/plate_appearances',
           params: {
             plate_appearance: {
               game_result_id: target_game.id, batter_box_number: 1,
               plate_result_id: 8, hit_direction_id: 9
             }
           },
           headers: auth_headers_for(user)

      other_batting_average.reload
      expect(other_batting_average.at_bats).to eq(50)
      expect(other_batting_average.hit).to eq(25)
    end
  end

  describe 'ユーザー通算打率が新旧の batting_average を合算して算出される' do
    let(:old_game) { create(:game_result, user:) }
    let(:new_game) { create(:game_result, user:) }

    before do
      create(:batting_average, game_result: old_game, user:,
                               at_bats: 3, hit: 1, two_base_hit: 0, three_base_hit: 0, home_run: 0,
                               total_bases: 1, runs_batted_in: 0, strike_out: 1, base_on_balls: 0,
                               hit_by_pitch: 0, sacrifice_hit: 0, sacrifice_fly: 0,
                               stealing_base: 0, caught_stealing: 0, error: 0)
    end

    it 'v2 で新仕様試合の打席を追加すると、aggregate_for_user は新旧合算した SUM を返す' do
      post '/api/v2/plate_appearances',
           params: {
             plate_appearance: {
               game_result_id: new_game.id, batter_box_number: 1,
               plate_result_id: 7, hit_direction_id: 10, rbi: 1
             }
           },
           headers: auth_headers_for(user)
      post '/api/v2/plate_appearances',
           params: {
             plate_appearance: {
               game_result_id: new_game.id, batter_box_number: 2,
               plate_result_id: 13
             }
           },
           headers: auth_headers_for(user)

      aggregated = BattingAverage.aggregate_for_user(user.id).reorder(nil).take
      # 旧 (at_bats=3, hit=1) + 新 (at_bats=2, hit=1) = 合算 (at_bats=5, hit=2)
      expect(aggregated.at_bats.to_i).to eq(5)
      expect(aggregated.hit.to_i).to eq(2)
    end
  end
end
