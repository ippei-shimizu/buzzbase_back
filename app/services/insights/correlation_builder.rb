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
    # metric_kind: :ratio3（打率/OPS などの 3 桁小数）/ :rate（三振率などの割合）
    PAIRS = [
      { key: 'swings_vs_ba', input: :total_swings, input_label: '素振りの本数',
        metric: :batting_average, metric_label: '打率', metric_kind: :ratio3, higher_metric_is_better: true },
      { key: 'practice_days_vs_ops', input: :practice_days, input_label: '練習した日数',
        metric: :ops, metric_label: 'OPS', metric_kind: :ratio3, higher_metric_is_better: true },
      { key: 'sleep_vs_k_rate', input: :sleep_hours, input_label: '睡眠時間',
        metric: :strikeout_rate, metric_label: '三振率', metric_kind: :rate, higher_metric_is_better: false },
      { key: 'condition_vs_ba', input: :condition_level, input_label: '体調の良さ',
        metric: :batting_average, metric_label: '打率', metric_kind: :ratio3, higher_metric_is_better: true }
    ].freeze

    def initialize(user:)
      @user = user
    end

    # @return [Array<Hash>] インサイトカードの配列
    def call
      inputs = weekly_inputs
      metrics = weekly_metrics
      PAIRS.map { |pair| build_card(pair, inputs, metrics) }
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
      direction = diff.positive? ? 'positive' : 'negative'
      {
        key: pair[:key],
        title: "#{pair[:input_label]}と#{pair[:metric_label]}",
        body: body_text(pair, diff),
        metric: pair[:metric].to_s,
        dimension: pair[:input].to_s,
        direction:,
        strength: strength_label(diff),
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

    def body_text(pair, diff)
      more_high = "#{pair[:input_label]}が多い週"
      formatted = format_diff(pair[:metric_kind], diff)
      verb = diff.positive? ? '高い' : '低い'
      "#{more_high}は、#{pair[:metric_label]}が#{formatted}#{verb}傾向があります。"
    end

    STRENGTH_THRESHOLD = 0.05

    # 差の大きさをラベル化（因果の強さではなくあくまで傾向の目安）。
    def strength_label(diff)
      diff.abs >= STRENGTH_THRESHOLD ? 'strong' : 'weak'
    end

    def format_diff(kind, diff)
      case kind
      when :ratio3 then format_ratio3(diff.abs)
      when :rate then "#{(diff.abs * 100).round(1)}ポイント"
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

    # 週開始日 => { total_swings:, practice_days:, sleep_hours:, condition_level: }
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

    def accumulate_condition_inputs(inputs)
      logs = @user.condition_logs.where(logged_on: window_start..)
      logs.group_by { |log| log.logged_on.beginning_of_week }.each do |week_start, week_logs|
        sleeps = week_logs.filter_map(&:sleep_hours)
        levels = week_logs.filter_map(&:fatigue_level)
        inputs[week_start][:sleep_hours] = mean(sleeps) if sleeps.any?
        inputs[week_start][:condition_level] = mean(levels) if levels.any?
      end
    end

    # 週開始日 => { batting_average:, ops:, strikeout_rate: }
    def weekly_metrics
      WeeklyBattingAggregator.new(user: @user, since: window_start).call
    end

    def mean(values)
      return 0.0 if values.empty?

      (values.sum.to_f / values.size)
    end
  end
end
