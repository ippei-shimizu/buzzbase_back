# frozen_string_literal: true

module Stats
  # batting_averages のスコープに含まれる試合に絞って走本塁打（ランニング本塁打）を数える。
  # batting_averages には内訳カラムが無いため、同じ試合集合の plate_appearances を数える。
  #
  # 旧仕様 PA を含む混在試合では batting_averages.home_run が再集計されず古いまま残るため、
  # 内数が母数を超えうる。フロントが home_run - inside_the_park_home_run で柵越え数を
  # 出しても負にならないよう、母数でクランプして「内数は母数を超えない」を保証する。
  module InsideTheParkHomeRunCounter
    module_function

    # @param batting_average_scope [ActiveRecord::Relation] 集計対象の batting_averages スコープ
    # @param user_id [Integer] 対象ユーザー
    # @param home_run_total [Integer] 同じスコープで集計した本塁打数（母数）
    # @return [Integer] 走本塁打の本数（0 〜 home_run_total）
    def count(batting_average_scope, user_id:, home_run_total:)
      count = plate_appearance_scope(batting_average_scope, user_id:).count
      [count, home_run_total].min
    end

    # 試合ごとの走本塁打数。日別テーブルのように試合単位で行を作るときに
    # 行ごとに COUNT を発行せず 1 クエリで引けるようにする。
    # @return [Hash{Integer => Integer}] game_result_id => 走本塁打数（0 件の試合はキー自体が無い）
    def count_by_game_result(batting_average_scope, user_id:)
      plate_appearance_scope(batting_average_scope, user_id:).group(:game_result_id).count
    end

    # 他の Stats 系 PA スコープと同じく新仕様 PA のみを対象にする。
    def plate_appearance_scope(batting_average_scope, user_id:)
      game_result_ids = batting_average_scope.unscope(:select, :group, :order)
                                             .select('batting_averages.game_result_id')
      PlateAppearance.where(user_id:, is_new_format: true, game_result_id: game_result_ids)
                     .home_run_type_inside_the_park
    end
  end
end
