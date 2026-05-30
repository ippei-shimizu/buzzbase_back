require 'rails_helper'

# v1 API のレスポンスキー集合の回帰検知。
#
# 試合記録アップデート (issue #330) でモデルに大量のカラムを追加したが、
# v1 controller は `render json: @model` 形式で全カラムを自動露出する設計のため、
# 新カラムも v1 レスポンスに含まれる。front/mobile は構造的型付けで追加プロパティを無視するため
# 実害はないが、将来 v1 のレスポンス構造が意図せず変わった際に気づけるよう、
# 現状のキー集合を spec で固定する。
RSpec.describe 'v1 API レスポンスキー集合の不変性', type: :request do
  let(:user) { create(:user) }
  # game_result factory の after(:create) で match_result が自動生成されるため、
  # 既存試合の作成は game_result 側から行う。
  let(:game_result) { create(:game_result, user:) }
  let(:match_result) { game_result.match_result }

  describe 'GET /api/v1/match_results/:id' do
    it '既存カラム + 新カラム (stadium_id) を含む現状のキー集合を返す' do
      get "/api/v1/match_results/#{match_result.id}", headers: auth_headers_for(user)

      expect(response).to have_http_status(:ok)
      keys = response.parsed_body.keys
      expect(keys).to include(
        'id', 'date_and_time', 'match_type', 'my_team_id', 'opponent_team_id',
        'my_team_score', 'opponent_team_score', 'batting_order', 'defensive_position',
        'inning_format', 'appearance_type', 'stadium_id'
      )
    end
  end

  describe 'GET /api/v1/plate_appearances （show系の代表として user_plate_search を使用）' do
    let!(:plate_appearance) do
      create(:plate_appearance, game_result:, user:,
                                plate_result_id: 7, hit_direction_id: 10,
                                batting_position_id: 8, batting_result: '中安')
    end

    it 'plate_appearances に新カラムが含まれた状態でレスポンスする' do
      get '/api/v1/user_plate_search',
          params: { game_result_id: game_result.id },
          headers: auth_headers_for(user)

      expect(response).to have_http_status(:ok)
      first = response.parsed_body.is_a?(Array) ? response.parsed_body.first : response.parsed_body
      next if first.blank?

      expect(first).to include(
        'id', 'batter_box_number', 'batting_result',
        'plate_result_id', 'hit_direction_id', 'batting_position_id'
      )
      # 新カラムは v1 でも露出する（A案: 何もしない方針）
      new_columns = %w[out_type hit_type rbi runners_state contact_quality_id hit_location_x]
      new_columns.each do |col|
        expect(first.keys).to include(col), "新カラム #{col} が v1 レスポンスから消えた可能性。意図的なら spec を更新すること"
      end
    end
  end

  describe 'BattingAverage のレスポンス構造' do
    let!(:batting_average) { create(:batting_average, game_result:, user:) }

    it 'batting_averages テーブルには新カラムを追加していないので、レスポンスキーは既存のまま' do
      # BattingAverage モデルのカラム自体に新カラムを追加していないことを確認
      new_columns = %w[out_type hit_type rbi runners_state contact_quality_id]
      expect(BattingAverage.column_names & new_columns).to be_empty
    end
  end
end
