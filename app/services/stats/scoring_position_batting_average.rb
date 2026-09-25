# frozen_string_literal: true

module Stats
  # batting_averages のスコープに含まれる試合に絞って得点圏打率を出す。
  # 打撃成績表の行（年・月・試合）と同じ試合集合で数えるため、絞り込みは batting_averages 側から引き継ぐ。
  #
  # 得点圏の判定は runners_state が必須のため、旧仕様 PA しか無い試合は母数に入らない。
  # 母数 0 を打率 .000 と区別できるよう、得点圏打数が 0 のときは nil を返す。
  module ScoringPositionBattingAverage
    module_function

    COUNT_COLUMNS = [
      Arel.sql(RunnersSituationAggregator::AT_BATS_COUNT_SQL),
      Arel.sql(RunnersSituationAggregator::HITS_COUNT_SQL)
    ].freeze

    # @param batting_average_scope [ActiveRecord::Relation] 集計対象の batting_averages スコープ
    # @param user_id [Integer] 対象ユーザー
    # @return [Float, nil] 得点圏打率。得点圏打数が 0 のときは nil
    def calculate(batting_average_scope, user_id:)
      at_bats, hits = plate_appearance_scope(batting_average_scope, user_id:).pick(*COUNT_COLUMNS)
      rate(hits:, at_bats:)
    end

    # 日別テーブルのように試合単位で行を作るときに、行ごとにクエリを発行せず 1 クエリで引く。
    # @return [Hash{Integer => Float}] game_result_id => 得点圏打率（得点圏打数 0 の試合はキー自体が無い）
    def calculate_by_game_result(batting_average_scope, user_id:)
      plate_appearance_scope(batting_average_scope, user_id:)
        .group(:game_result_id)
        .pluck(:game_result_id, *COUNT_COLUMNS)
        .filter_map { |game_result_id, at_bats, hits| [game_result_id, rate(hits:, at_bats:)] if at_bats.to_i.positive? }
        .to_h
    end

    def plate_appearance_scope(batting_average_scope, user_id:)
      game_result_ids = batting_average_scope.unscope(:select, :group, :order)
                                             .select('batting_averages.game_result_id')
      PlateAppearance.joins(:plate_result)
                     .where(user_id:, game_result_id: game_result_ids,
                            runners_state: RunnersSituationAggregator::SCORING_POSITION_STATES)
    end

    def rate(hits:, at_bats:)
      return nil if at_bats.to_i.zero?

      BattingFormulas.batting_average(total_hits: hits.to_i, at_bats: at_bats.to_i)
    end
  end
end
