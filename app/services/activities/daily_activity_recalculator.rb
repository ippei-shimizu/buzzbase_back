module Activities
  # 指定ユーザー・日付の activity_logs 行を全再計算する（冪等）。
  # practice_log（素振り自動生成ログ含む）/ match_result の after_commit から呼ばれ、
  # 草・Streak の集計基盤となる。コンディションログは集計対象外。
  #
  # 集計の前提:
  # - 日付バケットは JST。practice_log は logged_on（JST 日付）をそのまま使う。
  # - 素振り本数は source='shadow_swing' の practice_log.amount を集計する
  #   （ShadowSwingSession テーブルへ依存せず二重計上も避ける）。
  class DailyActivityRecalculator
    JST = 'Asia/Tokyo'.freeze

    SWING_L2 = 100
    SWING_L3 = 300
    SWING_L4 = 500

    # @param user_id [Integer]
    # @param date [Date] JST の日付
    def initialize(user_id:, date:)
      @user_id = user_id
      @date = date
    end

    # @return [ActivityLog, nil] 更新後のレコード。無活動日（強度0）なら削除して nil
    def call
      menu_count = practice_menu_count
      swing_count = total_swing_count
      game = game_on_day?
      level = intensity_level(menu_count, swing_count, game)

      activity_log = ActivityLog.find_or_initialize_by(user_id: @user_id, activity_date: @date)

      if level.zero?
        activity_log.destroy if activity_log.persisted?
        return nil
      end

      activity_log.update!(
        practice_menu_count: menu_count,
        total_swing_count: swing_count,
        has_game: game,
        intensity_level: level
      )
      activity_log
    end

    private

    # その日の練習ログの distinct メニュー数。
    # メニュー削除済みでも menu_name スナップショットで識別する。
    def practice_menu_count
      PracticeLog.where(user_id: @user_id, logged_on: @date)
                 .distinct
                 .count(Arel.sql('COALESCE(practice_menu_id::text, menu_name)'))
    end

    # 素振り由来の練習ログ合計本数。
    def total_swing_count
      PracticeLog.where(user_id: @user_id, logged_on: @date, source: 'shadow_swing')
                 .sum(:amount).to_i
    end

    # その JST 日に試合（game_result に紐づく match_result）が存在するか。
    def game_on_day?
      zone = Time.find_zone(JST)
      day_start = zone.local(@date.year, @date.month, @date.day)
      day_end = day_start + 1.day
      MatchResult.joins(:game_result)
                 .where(game_results: { user_id: @user_id })
                 .exists?(date_and_time: day_start...day_end)
    end

    # 強度 = max(メニュー数レベル, 素振り本数レベル, 試合)。各軸は独立に L0〜L4 へ写像する。
    def intensity_level(menu_count, swing_count, game)
      return 4 if game

      [menu_count.clamp(0, 4), swing_level(swing_count)].max
    end

    def swing_level(swing_count)
      return 4 if swing_count >= SWING_L4
      return 3 if swing_count >= SWING_L3
      return 2 if swing_count >= SWING_L2

      0
    end
  end
end
