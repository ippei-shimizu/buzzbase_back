module Insights
  # 練習量・コンディション × 成績の「傾向」を週次で集計し、言い切りカードを生成する。
  #
  # 因果ではなく傾向であることを前提とし、週（JST 月〜日）単位で入力量（説明変数）と
  # 成績（目的変数）を揃え、入力量の中央値で上位群 / 下位群に分けて成績平均の差を出す。
  # サンプル週が閾値未満のペアは sufficient:false の非断定カードにする（誤った断定を避ける）。
  class CorrelationBuilder
    JST = 'Asia/Tokyo'.freeze
    WINDOW_WEEKS = 16
    MIN_PAIRED_WEEKS = 4

    # 分析する (入力量 × 成績) ペアの定義。
    # input_more: 入力量が「多い/長い/良い/高い」など本文で使う語。
    # metric_kind: :ratio3（打率/OPS の 3 桁小数）/ :decimal2（防御率/WHIP）/ :per9（与四球率/9）
    BATTING_PAIRS = [
      { key: 'swings_vs_ba', input: :total_swings, input_label: '素振りの本数', input_more: '多い',
        metric: :batting_average, metric_label: '打率', metric_kind: :ratio3, higher_metric_is_better: true },
      { key: 'practice_days_vs_ops', input: :practice_days, input_label: '練習した日数', input_more: '多い',
        metric: :ops, metric_label: 'OPS', metric_kind: :ratio3, higher_metric_is_better: true },
      { key: 'sleep_vs_ba', input: :sleep_hours, input_label: '睡眠時間', input_more: '長い',
        metric: :batting_average, metric_label: '打率', metric_kind: :ratio3, higher_metric_is_better: true },
      { key: 'physical_vs_ops', input: :physical_level, input_label: '体調の良さ', input_more: '良い',
        metric: :ops, metric_label: 'OPS', metric_kind: :ratio3, higher_metric_is_better: true },
      { key: 'energy_vs_ba', input: :energy_level, input_label: '元気さ（疲れの少なさ）', input_more: '高い',
        metric: :batting_average, metric_label: '打率', metric_kind: :ratio3, higher_metric_is_better: true }
    ].freeze

    # 投手指標は登板が無い週を除外して集計するため、登板データがある場合のみ対象にする。
    PITCHING_PAIRS = [
      { key: 'practice_days_vs_era', input: :practice_days, input_label: '練習した日数', input_more: '多い',
        metric: :era, metric_label: '防御率', metric_kind: :decimal2, higher_metric_is_better: false },
      { key: 'sleep_vs_bb9', input: :sleep_hours, input_label: '睡眠時間', input_more: '長い',
        metric: :bb_per9, metric_label: '与四球率', metric_kind: :per9, higher_metric_is_better: false },
      { key: 'physical_vs_era', input: :physical_level, input_label: '体調の良さ', input_more: '良い',
        metric: :era, metric_label: '防御率', metric_kind: :decimal2, higher_metric_is_better: false }
    ].freeze

    def initialize(user:)
      @user = user
    end

    # @return [Array<Hash>] インサイトカードの配列
    def call
      inputs = weekly_inputs
      batting = weekly_batting_metrics
      cards = BATTING_PAIRS.map { |pair| build_card(pair, inputs, batting) }
      pitching = weekly_pitching_metrics
      cards += PITCHING_PAIRS.map { |pair| build_card(pair, inputs, pitching) } if pitching.any?
      cards
    end

    private

    def build_card(pair, inputs, metrics)
      paired = paired_weeks(pair, inputs, metrics)
      return insufficient_card(pair, paired.size) if paired.size < MIN_PAIRED_WEEKS

      low, high = split_by_input_median(paired)
      diff = mean(high.pluck(:metric)) - mean(low.pluck(:metric))
      card(pair, paired.size, diff)
    end

    # 入力量・成績の両方が記録された週だけを対象にする。
    def paired_weeks(pair, inputs, metrics)
      week_starts.filter_map do |week_start|
        input = inputs.dig(week_start, pair[:input])
        metric = metrics.dig(week_start, pair[:metric])
        next if input.nil? || metric.nil?

        { input:, metric: }
      end
    end

    # 入力量の中央値で下位群 / 上位群に分ける。
    def split_by_input_median(paired)
      sorted = paired.sort_by { |week| week[:input] }
      half = sorted.size / 2
      [sorted.first(half), sorted.last(sorted.size - half)]
    end

    def card(pair, sample_weeks, diff)
      # 成績が良くなった向きかは metric の良し悪しに依存する（防御率は下がるほど良い）。
      is_good = diff.positive? == pair[:higher_metric_is_better]
      {
        key: pair[:key],
        title: "#{pair[:input_label]}と#{pair[:metric_label]}",
        body: body_text(pair, diff, is_good),
        metric: pair[:metric].to_s,
        dimension: pair[:input].to_s,
        direction: is_good ? 'positive' : 'negative',
        strength: strength_label(pair, diff),
        sample_weeks:,
        sufficient: true
      }
    end

    def insufficient_card(pair, sample_weeks)
      {
        key: pair[:key],
        title: "#{pair[:input_label]}と#{pair[:metric_label]}",
        body: "#{pair[:input_label]}と#{pair[:metric_label]}の関係は、もう少しデータが集まると分かります。",
        metric: pair[:metric].to_s,
        dimension: pair[:input].to_s,
        direction: 'unknown',
        strength: 'insufficient',
        sample_weeks:,
        sufficient: false
      }
    end

    def body_text(pair, diff, is_good)
      formatted = format_diff(pair[:metric_kind], diff)
      verb = diff.positive? ? '高い' : '低い'
      takeaway = is_good ? 'いまの取り組みが効いていそう。この調子で続けよう。' : '少し見直すと変わるかもしれません。'
      "#{pair[:input_label]}が#{pair[:input_more]}週ほど、#{pair[:metric_label]}が#{formatted}#{verb}傾向。#{takeaway}"
    end

    # 差の大きさをラベル化（因果の強さではなくあくまで傾向の目安）。metric の桁で閾値が異なる。
    STRENGTH_THRESHOLDS = { ratio3: 0.05, decimal2: 0.5, per9: 0.5 }.freeze

    def strength_label(pair, diff)
      diff.abs >= STRENGTH_THRESHOLDS.fetch(pair[:metric_kind], 0.05) ? 'strong' : 'weak'
    end

    def format_diff(kind, diff)
      case kind
      when :ratio3 then format_ratio3(diff.abs)
      when :decimal2 then format('%.2f', diff.abs)
      when :per9 then format('%.1f', diff.abs)
      end
    end

    # .045 のように先頭の 0 を省いた 3 桁小数にする。
    def format_ratio3(value)
      format('.%03d', (value * 1000).round)
    end

    # ---- 週次集計 ----

    def week_starts
      @week_starts ||= begin
        this_week = Time.find_zone(JST).today.beginning_of_week
        (0...WINDOW_WEEKS).map { |offset| this_week - (offset * 7) }
      end
    end

    def window_start
      week_starts.last
    end

    # 週開始日 => { total_swings:, practice_days:, sleep_hours:, physical_level:, energy_level: }
    def weekly_inputs
      inputs = Hash.new { |hash, key| hash[key] = {} }
      accumulate_activity_inputs(inputs)
      accumulate_condition_inputs(inputs)
      inputs
    end

    def accumulate_activity_inputs(inputs)
      logs = @user.activity_logs.where(activity_date: window_start..)
      logs.group_by { |log| log.activity_date.beginning_of_week }.each do |week_start, week_logs|
        inputs[week_start][:total_swings] = week_logs.sum(&:total_swing_count)
        inputs[week_start][:practice_days] = week_logs.count { |log| log.intensity_level >= 1 }
      end
    end

    # physical_level は好調度、fatigue_level は元気度（どちらも高いほど良い、1〜4）。
    def accumulate_condition_inputs(inputs)
      logs = @user.condition_logs.where(logged_on: window_start..)
      logs.group_by { |log| log.logged_on.beginning_of_week }.each do |week_start, week_logs|
        put_mean(inputs[week_start], :sleep_hours, week_logs.filter_map(&:sleep_hours))
        put_mean(inputs[week_start], :physical_level, week_logs.filter_map(&:physical_level))
        put_mean(inputs[week_start], :energy_level, week_logs.filter_map(&:fatigue_level))
      end
    end

    def put_mean(bucket, key, values)
      bucket[key] = mean(values) if values.any?
    end

    # 週開始日 => { batting_average:, ops:, strikeout_rate: }
    def weekly_batting_metrics
      @weekly_batting_metrics ||= WeeklyBattingAggregator.new(user: @user, since: window_start).call
    end

    # 週開始日 => { era:, whip:, bb_per9: }（登板が無い週は含まれない）
    def weekly_pitching_metrics
      @weekly_pitching_metrics ||= WeeklyPitchingAggregator.new(user: @user, since: window_start).call
    end

    def mean(values)
      return 0.0 if values.empty?

      (values.sum.to_f / values.size)
    end
  end
end
