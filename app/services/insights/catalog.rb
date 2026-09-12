module Insights
  # 「練習と成績のつながり」で選べる入力・成績の定義（単一情報源）。
  # フロントの constants/insight.ts とキーを一致させること。
  module Catalog
    # 固定入力（コンディション・練習量）。practice_menu は別扱い（ラベルはメニュー名）。
    INPUTS = {
      'total_swings' => { label: '素振りの本数', more: '多い' },
      'practice_days' => { label: '練習した日数', more: '多い' },
      'sleep_hours' => { label: '睡眠時間', more: '長い' },
      'physical_level' => { label: '体調の良さ', more: '良い' },
      'energy_level' => { label: '元気さ（疲れの少なさ）', more: '高い' }
    }.freeze

    FIXED_INPUT_KEYS = INPUTS.keys.freeze
    INPUT_TYPES = (FIXED_INPUT_KEYS + ['practice_menu']).freeze

    # 成績指標。kind は表示整形、side は集計元（打撃/投手）、higher_is_better は direction 判定に使う。
    METRICS = {
      'batting_average' => { label: '打率', kind: :ratio3, side: :batting, higher_is_better: true },
      'on_base_percentage' => { label: '出塁率', kind: :ratio3, side: :batting, higher_is_better: true },
      'slugging_percentage' => { label: '長打率', kind: :ratio3, side: :batting, higher_is_better: true },
      'ops' => { label: 'OPS', kind: :ratio3, side: :batting, higher_is_better: true },
      'era' => { label: '防御率', kind: :decimal2, side: :pitching, higher_is_better: false },
      'whip' => { label: 'WHIP', kind: :decimal2, side: :pitching, higher_is_better: false },
      'bb_per9' => { label: '与四球率', kind: :per9, side: :pitching, higher_is_better: false }
    }.freeze

    METRIC_KEYS = METRICS.keys.freeze

    # おすすめ（固定）の入力 × 成績ペア。spec と同じ形。
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

    # 投手指標は登板が無い週を除外するため、登板データがある場合のみ対象にする。
    PITCHING_PAIRS = [
      { key: 'practice_days_vs_era', input: :practice_days, input_label: '練習した日数', input_more: '多い',
        metric: :era, metric_label: '防御率', metric_kind: :decimal2, higher_metric_is_better: false },
      { key: 'sleep_vs_bb9', input: :sleep_hours, input_label: '睡眠時間', input_more: '長い',
        metric: :bb_per9, metric_label: '与四球率', metric_kind: :per9, higher_metric_is_better: false },
      { key: 'physical_vs_era', input: :physical_level, input_label: '体調の良さ', input_more: '良い',
        metric: :era, metric_label: '防御率', metric_kind: :decimal2, higher_metric_is_better: false }
    ].freeze
  end
end
