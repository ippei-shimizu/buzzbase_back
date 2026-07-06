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

    def initialize(user:)
      @user = user
    end

    # @param combinations [Array<InsightCombination>] ユーザー定義の組み合わせ
    # @return [Array<Hash>] インサイトカードの配列（プリセット + 自作）
    def call(combinations: [])
      cards = preset_cards
      cards + combinations.map { |combination| custom_card(combination) }
    end

    private

    # おすすめ（固定）カード。投手は登板がある時のみ。
    def preset_cards
      cards = Catalog::BATTING_PAIRS.map { |pair| build_card(preset_spec(pair)) }
      cards += Catalog::PITCHING_PAIRS.map { |pair| build_card(preset_spec(pair)) } if weekly_pitching_metrics.any?
      cards
    end

    def preset_spec(pair)
      pair.merge(id: nil, input_series: fixed_input_series(pair[:input]),
                 metric_series: metric_series_for(pair[:metric]))
    end

    def custom_card(combination)
      build_card(combo_spec(combination))
    end

    def build_card(spec)
      paired = paired_weeks(spec[:input_series], spec[:metric_series])
      return insufficient_card(spec, paired.size) if paired.size < MIN_PAIRED_WEEKS

      low, high = split_by_input_median(paired)
      diff = mean(high.pluck(:metric)) - mean(low.pluck(:metric))
      card(spec, paired.size, diff)
    end

    # 入力量・成績の両方が記録された週だけを対象にする。
    def paired_weeks(input_series, metric_series)
      week_starts.filter_map do |week_start|
        input = input_series[week_start]
        metric = metric_series[week_start]
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

    def card(spec, sample_weeks, diff)
      # 成績が良くなった向きかは metric の良し悪しに依存する（防御率は下がるほど良い）。
      is_good = diff.positive? == spec[:higher_metric_is_better]
      {
        key: spec[:key],
        id: spec[:id],
        title: "#{spec[:input_label]}と#{spec[:metric_label]}",
        body: CardText.body(spec, diff, is_good),
        metric: spec[:metric].to_s,
        dimension: spec[:input].to_s,
        direction: is_good ? 'positive' : 'negative',
        strength: CardText.strength(spec, diff),
        sample_weeks:,
        sufficient: true
      }
    end

    def insufficient_card(spec, sample_weeks)
      {
        key: spec[:key],
        id: spec[:id],
        title: "#{spec[:input_label]}と#{spec[:metric_label]}",
        body: "#{spec[:input_label]}と#{spec[:metric_label]}の関係は、もう少しデータが集まると分かります。",
        metric: spec[:metric].to_s,
        dimension: spec[:input].to_s,
        direction: 'unknown',
        strength: 'insufficient',
        sample_weeks:,
        sufficient: false
      }
    end

    # ---- 系列（週 => 数値）の解決 ----

    def fixed_input_series(input_key)
      weekly_inputs.transform_values { |by_key| by_key[input_key] }
    end

    def metric_series_for(metric)
      side = Catalog::METRICS.fetch(metric.to_s)[:side]
      source = side == :batting ? weekly_batting_metrics : weekly_pitching_metrics
      source.transform_values { |by_metric| by_metric[metric] }
    end

    def combo_spec(combination)
      metric = combination.metric.to_sym
      meta = Catalog::METRICS.fetch(combination.metric)
      input_label, input_more = combo_input_labels(combination)
      {
        key: "custom_#{combination.id}", id: combination.id,
        input: combination.input_type, input_label:, input_more:,
        metric:, metric_label: meta[:label], metric_kind: meta[:kind],
        higher_metric_is_better: meta[:higher_is_better],
        input_series: combo_input_series(combination), metric_series: metric_series_for(metric)
      }
    end

    def combo_input_labels(combination)
      return ["#{combination.practice_menu&.name}の量", '多い'] if combination.input_type == 'practice_menu'

      meta = Catalog::INPUTS.fetch(combination.input_type)
      [meta[:label], meta[:more]]
    end

    def combo_input_series(combination)
      return fixed_input_series(combination.input_type.to_sym) unless combination.input_type == 'practice_menu'
      return {} unless combination.practice_menu

      WeeklyMenuVolumeAggregator.new(user: @user, menu: combination.practice_menu, since: window_start).call
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
