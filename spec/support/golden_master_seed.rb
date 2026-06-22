# frozen_string_literal: true

# golden master 用の決定的な代表データセットを構築する。
#
# 全ての値は固定で、集計サービスの出力は auto-increment な id に依存しない
# （出力は集計値とマスタ id のみ）。よって何度実行しても同じ golden が得られる。
#
# 含むケース:
#   - 旧仕様（v1）の試合: batting_average を直書き（既存ユーザー相当・recalc 保護対象）
#   - 新仕様の試合: plate_appearances を固定値で投入し recalculator で集計
#   - 混在試合: 旧 PA と新 PA が混ざる試合（recalc は触ってはいけない）
module GoldenMasterSeed
  # plate_results マスタ ID（plate_results.yml と一致）
  SINGLE = 7
  DOUBLE = 8
  TRIPLE = 9
  HOME_RUN = 10
  SACRIFICE_FLY = 12
  STRIKE_OUT = 13
  BASE_ON_BALLS = 15
  GROUND_OUT = 1
  FLY_OUT = 2

  module_function

  # @return [Hash] :user, :old_game_ids, :mixed_game_id, :new_game_id
  def build!
    user = FactoryBot.create(:user)
    old_game_ids = build_old_games(user)
    mixed_game_id = build_mixed_game(user)
    new_game_id = build_new_game(user)
    { user:, old_game_ids:, mixed_game_id:, new_game_id: }
  end

  # 既存 v1 データ。batting_average を直書きし、新仕様 PA は持たない。
  def build_old_games(user)
    [
      { date: '2026-04-01', at_bats: 4, hit: 1, two_base_hit: 1, total_bases: 3, base_on_balls: 1, strike_out: 1 },
      { date: '2026-04-15', at_bats: 3, hit: 1, home_run: 1, total_bases: 5, strike_out: 1 }
    ].map do |attrs|
      game = create_game(user, date: attrs[:date])
      FactoryBot.create(
        :batting_average,
        game_result: game, user:,
        plate_appearances: attrs[:at_bats] + attrs.fetch(:base_on_balls, 0),
        times_at_bat: attrs[:at_bats],
        at_bats: attrs[:at_bats], hit: attrs[:hit],
        two_base_hit: attrs.fetch(:two_base_hit, 0), three_base_hit: 0,
        home_run: attrs.fetch(:home_run, 0), total_bases: attrs[:total_bases],
        base_on_balls: attrs.fetch(:base_on_balls, 0), strike_out: attrs.fetch(:strike_out, 0)
      )
      game.id
    end
  end

  # 旧 PA と新 PA が混在する試合。recalculator は触らず、直書き集計値を保護すべき。
  def build_mixed_game(user)
    game = create_game(user, date: '2026-04-20')
    FactoryBot.create(:batting_average, game_result: game, user:,
                                        at_bats: 3, times_at_bat: 3, hit: 2, total_bases: 2)
    FactoryBot.create(:plate_appearance, game_result: game, user:, batter_box_number: 1,
                                         is_new_format: false, plate_result_id: SINGLE)
    FactoryBot.create(:plate_appearance, game_result: game, user:, batter_box_number: 2,
                                         is_new_format: true, plate_result_id: SINGLE,
                                         hit_direction_id: 10)
    game.id
  end

  # 新仕様の試合。固定値の打席を投入し、recalculator で batting_average を生成する。
  def build_new_game(user)
    game = create_game(user, date: '2026-05-01')
    new_appearances.each_with_index do |attrs, index|
      FactoryBot.create(:plate_appearance, game_result: game, user:,
                                           batter_box_number: index + 1, is_new_format: true, **attrs)
    end
    Stats::BattingAverageRecalculator.new(game_result_id: game.id, user_id: user.id).call
    game.id
  end

  # 新仕様試合の打席（固定値）。安打には打球座標、アウトには out_type、各打席にランナー状況を持たせる。
  def new_appearances
    [
      { plate_result_id: SINGLE, hit_direction_id: 10, hit_location_x: 0.100, hit_location_y: 0.500,
        runners_state: :no_runner, rbi: 0, run_scored: 1 },
      { plate_result_id: DOUBLE, hit_direction_id: 8, hit_location_x: 0.300, hit_location_y: 0.620,
        runners_state: :first, rbi: 1, run_scored: 0 },
      { plate_result_id: TRIPLE, hit_direction_id: 11, hit_location_x: 0.250, hit_location_y: 0.700,
        runners_state: :second, rbi: 1, run_scored: 0 },
      { plate_result_id: HOME_RUN, hit_direction_id: 12, hit_location_x: 0.400, hit_location_y: 0.800,
        runners_state: :bases_loaded, rbi: 4, run_scored: 1 },
      { plate_result_id: GROUND_OUT, out_type: :ground_ball, hit_direction_id: 4, runners_state: :third },
      { plate_result_id: FLY_OUT, out_type: :fly_ball, hit_direction_id: 10, runners_state: :first_second },
      { plate_result_id: STRIKE_OUT, swing_type: :swinging, runners_state: :first_third },
      { plate_result_id: BASE_ON_BALLS, runners_state: :second_third, rbi: 1 },
      { plate_result_id: SACRIFICE_FLY, out_type: :fly_ball, hit_direction_id: 10, runners_state: :third, rbi: 1 }
    ]
  end

  def create_game(user, date:)
    game = FactoryBot.create(:game_result, user:)
    game.match_result.update!(date_and_time: Time.zone.parse("#{date} 12:00:00"), match_type: 'regular')
    game
  end
end
