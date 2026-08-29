module PeriodicReviews
  # 週次 / 月次の振り返りレポートを生成（upsert）する。
  # 練習量・Streak・成績（全員に見せる基本部）に加え、課題別内訳・コンディション・
  # 練習メニュー別内訳・ノート記録日数・目標進捗・相関インサイト（Pro 限定の詳細部）を
  # summary にまとめて保存する。出し分けはシリアライザ側。
  class Generator # rubocop:disable Metrics/ClassLength
    JST = 'Asia/Tokyo'.freeze

    # summary の肥大化と、レポート生成バッチ（全ユーザーループ）のクエリ数増加を防ぐため、
    # 件数が可変の内訳には上限を設ける。
    PRACTICE_MENU_LIMIT = 5
    GOALS_LIMIT = 3

    # @param user [User]
    # @param period_type [String] 'weekly' / 'monthly'
    # @param period_start [Date] 期間の開始日（週=月曜 / 月=1日）
    def initialize(user:, period_type:, period_start:)
      @user = user
      @period_type = period_type
      @period_start = period_start
    end

    # @return [PeriodicReview] 保存済みレポート
    def call
      review = @user.periodic_reviews.find_or_initialize_by(period_type: @period_type, period_start: @period_start)
      review.update!(period_end:, summary: build_summary)
      review
    end

    private

    def period_end
      @period_end ||= @period_type == 'monthly' ? @period_start.end_of_month : @period_start + 6
    end

    # 月次は月ごとに日数が異なるため、固定日数ではなく前月の暦月で比較する。
    def previous_range
      if @period_type == 'monthly'
        previous_month_start = (@period_start - 1.month).beginning_of_month
        previous_month_start..previous_month_start.end_of_month
      else
        length = (period_end - @period_start).to_i + 1
        (@period_start - length)..(@period_start - 1)
      end
    end

    def build_summary
      basic_summary.merge(advanced_summary)
    end

    def basic_summary
      logs = activity_logs_in(range)
      {
        'period_type' => @period_type,
        'practice_days' => logs.count { |log| log.intensity_level >= 1 },
        'total_swings' => logs.sum(&:total_swing_count),
        'active_days' => logs.size,
        'streak_current' => Activities::StreakCalculator.new(@user).current,
        'batting' => batting_summary,
        'pitching' => pitching_summary
      }
    end

    def advanced_summary
      {
        'theme_breakdown' => theme_breakdown,
        'condition' => condition_summary,
        'practice_menus' => practice_menu_breakdown,
        'note_days' => note_days,
        'goals' => goals_summary,
        'insight' => representative_insight
      }
    end

    def range
      @range ||= @period_start..period_end
    end

    def activity_logs_in(date_range)
      @user.activity_logs.where(activity_date: date_range).to_a
    end

    # 取組中の課題ごとの、この期間の練習セッション数。
    def theme_breakdown
      @user.improvement_themes.where(status: 'open').map do |theme|
        {
          'id' => theme.id,
          'title' => theme.title,
          'practice_count' => theme.practice_sessions.where(logged_on: range).count
        }
      end
    end

    def condition_summary
      logs = @user.condition_logs.where(logged_on: range).to_a
      {
        'sleep_hours_avg' => average(logs.filter_map(&:sleep_hours)),
        'fatigue_level_avg' => average(logs.filter_map(&:fatigue_level)),
        'physical_level_avg' => average(logs.filter_map(&:physical_level))
      }
    end

    # 練習メニュー別の実施内訳。削除・アーカイブ済みメニューでも practice_logs.menu_name に
    # スナップショットが残るため、practice_menu_id ではなく名前で名寄せする。
    # 上限を超えた分は件数（other_count）だけ持つ。
    def practice_menu_breakdown
      rows = @user.practice_logs.where(logged_on: range)
                  .group(:menu_name)
                  .pluck(:menu_name, Arel.sql('COUNT(*)'),
                         Arel.sql('SUM(COALESCE(amount, 0))'), Arel.sql('MAX(unit_label)'))
      # 単位（本・分など）が混在し量どうしを比較できないため、実施回数を第一キーにする。
      sorted = rows.sort_by { |_, count, amount, _| [-count, -amount.to_f] }
      items = sorted.first(PRACTICE_MENU_LIMIT).map do |name, count, amount, unit|
        { 'name' => name, 'count' => count, 'total_amount' => amount.to_f.round(2), 'unit_label' => unit }
      end
      { 'items' => items, 'other_count' => [sorted.size - items.size, 0].max }
    end

    # 野球ノートを書いた日数。同日に複数ノートがあっても1日として数える。
    def note_days
      @user.baseball_notes.where(date: range).distinct.count(:date)
    end

    # 期間に重なる進行中の目標を締切の近い順に上限件数だけ載せる。
    # ProgressCalculator は目標ごとに集計クエリを発行するため、
    # バッチ全体の実行時間を抑える目的で上限は必須。
    def goals_summary
      goals = @user.goals.active
                   .where(deadline: @period_start..)
                   .where('month_start IS NULL OR month_start <= ?', period_end)
                   .order(:deadline).limit(GOALS_LIMIT)
      goals.map { |goal| goal_entry(goal) }
    end

    # kind ごとに current_value の意味が違う（numeric=自動集計 / manual=手入力 /
    # qualitative=数値なし）ため、表示ラベルの解決に必要な metric_key /
    # custom_metric_label をそのまま渡してクライアント側の既存ラベル定義に委ねる。
    def goal_entry(goal)
      calculator = Goals::ProgressCalculator.new(goal)
      {
        'id' => goal.id,
        'title' => goal.title,
        'kind' => goal.kind,
        'metric_key' => goal.metric_key,
        'custom_metric_label' => goal.custom_metric_label,
        'current_value' => calculator.current_value&.to_f,
        'target_value' => goal.target_value&.to_f,
        'progress_percent' => calculator.progress_percent.to_f,
        'achieved' => calculator.achieved?,
        'deadline' => goal.deadline.strftime('%Y-%m-%d')
      }
    end

    def batting_summary
      agg = batting_aggregates(range)
      obp = Stats::BattingFormulas.on_base_percentage(
        total_hits: agg[:total_hits], base_on_balls: agg[:bb], hit_by_pitch: agg[:hbp],
        at_bats: agg[:at_bats], sacrifice_fly: agg[:sf]
      )
      slg = Stats::BattingFormulas.slugging_percentage(total_bases: agg[:total_bases], at_bats: agg[:at_bats])
      current = Stats::BattingFormulas.batting_average(total_hits: agg[:total_hits], at_bats: agg[:at_bats])
      previous = batting_average_for(previous_range)
      {
        'batting_average' => current,
        'on_base_percentage' => obp,
        'slugging_percentage' => slg,
        'ops' => Stats::BattingFormulas.ops(obp:, slg:),
        'previous_batting_average' => previous,
        'delta' => (current - previous).round(3)
      }.merge(batting_counts(agg))
    end

    # 期間中の実数カウント。安打は NPB 標準（単打+二塁打+三塁打+本塁打）で、
    # 「単打のみ」を保持する batting_averages.hit 列とは意味が違う点に注意。
    def batting_counts(agg)
      {
        'hits' => agg[:total_hits],
        'two_base_hits' => agg[:two_base_hit],
        'three_base_hits' => agg[:three_base_hit],
        'home_runs' => agg[:home_run],
        'stolen_bases' => agg[:stealing_base],
        'strikeouts' => agg[:strike_out],
        'scoring_position' => scoring_position_summary
      }
    end

    # 得点圏は runners_state 必須の新フォーマット打席だけが母数になる。旧データのみの
    # ユーザーは母数 0 になるため、打率は 0.0 ではなく nil（未計測）で保存し、
    # クライアント側の「-」表示に落とす。
    def scoring_position_summary
      counts = Stats::RunnersSituationAggregator.new(user_id: @user.id, date_range: range).call
      {
        'batting_average' => counts[:at_bats].zero? ? nil : counts[:batting_average],
        'at_bats' => counts[:at_bats],
        'hits' => counts[:hits]
      }
    end

    # 投手成績。登板が無ければ率系（ERA / WHIP / K/9）は nil。
    # ERA / K9 は Stats::EraTrendService 等と同じく、試合ごとの inning_format（7 or 9）で
    # earned_run / strikeouts を加重してから投球回で割る（7回制混在時のズレを防ぐ）。
    # 一方「奪三振」「自責点」等の表示用カウントは実数（加重なし）で別キーに持ち、
    # 加重値そのものは summary に出さない。
    def pitching_summary
      agg = pitching_aggregates
      innings = agg[:innings]
      {
        'appearances' => agg[:appearances],
        'innings_pitched' => innings.round(1),
        'era' => innings.zero? ? nil : (agg[:weighted_earned] / innings).round(2),
        'whip' => innings.zero? ? nil : ((agg[:base_on_balls] + agg[:hits_allowed]) / innings).round(2),
        'k_per_9' => innings.zero? ? nil : (agg[:weighted_strikeouts] / innings).round(1),
        'strikeouts' => agg[:strikeouts],
        'base_on_balls' => agg[:base_on_balls].to_i,
        'hit_by_pitch' => agg[:hit_by_pitch],
        'hits_allowed' => agg[:hits_allowed].to_i,
        'home_runs_allowed' => agg[:home_runs_allowed],
        'runs_allowed' => agg[:runs_allowed],
        'earned_runs' => agg[:earned_runs]
      }
    end

    def pitching_aggregates
      date_sql = Stats::JstDateSql::DATE_AND_TIME_JST_SQL
      row = @user.game_results.joins(:match_result, :pitching_result)
                 .where("DATE(#{date_sql}) BETWEEN ? AND ?", range.first, range.last)
                 .pick(
                   Arel.sql('COUNT(*)'),
                   Arel.sql('SUM(COALESCE(pitching_results.innings_pitched, 0))'),
                   Arel.sql('SUM(COALESCE(pitching_results.earned_run, 0) * match_results.inning_format)'),
                   Arel.sql('SUM(COALESCE(pitching_results.strikeouts, 0) * match_results.inning_format)'),
                   Arel.sql('SUM(COALESCE(pitching_results.hits_allowed, 0))'),
                   Arel.sql('SUM(COALESCE(pitching_results.base_on_balls, 0))'),
                   Arel.sql('SUM(COALESCE(pitching_results.hit_by_pitch, 0))'),
                   Arel.sql('SUM(COALESCE(pitching_results.strikeouts, 0))'),
                   Arel.sql('SUM(COALESCE(pitching_results.home_runs_hit, 0))'),
                   Arel.sql('SUM(COALESCE(pitching_results.run_allowed, 0))'),
                   Arel.sql('SUM(COALESCE(pitching_results.earned_run, 0))')
                 )
      build_pitching_aggregates(Array.wrap(row))
    end

    def build_pitching_aggregates(row)
      appearances, innings, weighted_earned, weighted_strikeouts,
        hits_allowed, base_on_balls, hit_by_pitch, strikeouts,
        home_runs_allowed, runs_allowed, earned_runs = row
      {
        appearances: appearances.to_i, innings: innings.to_f,
        weighted_earned: weighted_earned.to_f, weighted_strikeouts: weighted_strikeouts.to_f,
        hits_allowed: hits_allowed.to_f, base_on_balls: base_on_balls.to_f,
        hit_by_pitch: hit_by_pitch.to_i, strikeouts: strikeouts.to_i,
        home_runs_allowed: home_runs_allowed.to_i, runs_allowed: runs_allowed.to_i,
        earned_runs: earned_runs.to_i
      }
    end

    def batting_aggregates(date_range)
      date_sql = Stats::JstDateSql::DATE_AND_TIME_JST_SQL
      row = @user.game_results.joins(:match_result, :batting_average)
                 .where("DATE(#{date_sql}) BETWEEN ? AND ?", date_range.first, date_range.last)
                 .pick(
                   Arel.sql("SUM(#{Stats::BattingFormulas::TOTAL_HITS_SQL})"),
                   Arel.sql('SUM(COALESCE(batting_averages.at_bats, 0))'),
                   Arel.sql('SUM(COALESCE(batting_averages.total_bases, 0))'),
                   Arel.sql('SUM(COALESCE(batting_averages.base_on_balls, 0))'),
                   Arel.sql('SUM(COALESCE(batting_averages.hit_by_pitch, 0))'),
                   Arel.sql('SUM(COALESCE(batting_averages.sacrifice_fly, 0))'),
                   Arel.sql('SUM(COALESCE(batting_averages.two_base_hit, 0))'),
                   Arel.sql('SUM(COALESCE(batting_averages.three_base_hit, 0))'),
                   Arel.sql('SUM(COALESCE(batting_averages.home_run, 0))'),
                   Arel.sql('SUM(COALESCE(batting_averages.stealing_base, 0))'),
                   Arel.sql('SUM(COALESCE(batting_averages.strike_out, 0))')
                 )
      keys = %i[total_hits at_bats total_bases bb hbp sf
                two_base_hit three_base_hit home_run stealing_base strike_out]
      keys.zip(Array.wrap(row).map(&:to_i)).to_h
    end

    # 期間中で最も傾向が強い（strong かつ十分なサンプル）インサイトを1つ選ぶ。
    def representative_insight
      cards = Insights::CorrelationBuilder.new(user: @user).call
      cards.select { |card| card[:sufficient] }.max_by { |card| card[:strength] == 'strong' ? 1 : 0 }
    end

    # 指定 JST 日付レンジの打率（総安打 / 打数）。
    def batting_average_for(date_range)
      date_sql = Stats::JstDateSql::DATE_AND_TIME_JST_SQL
      rows = @user.game_results.joins(:match_result, :batting_average)
                  .where("DATE(#{date_sql}) BETWEEN ? AND ?", date_range.first, date_range.last)
                  .pluck(Arel.sql("SUM(#{Stats::BattingFormulas::TOTAL_HITS_SQL})"),
                         Arel.sql('SUM(COALESCE(batting_averages.at_bats, 0))'))
      total_hits, at_bats = rows.first
      Stats::BattingFormulas.batting_average(total_hits: total_hits.to_i, at_bats: at_bats.to_i)
    end

    def average(values)
      return nil if values.empty?

      (values.sum.to_f / values.size).round(1)
    end
  end
end
