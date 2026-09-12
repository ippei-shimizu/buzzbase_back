module Insights
  # インサイトカードの本文・強弱ラベル・数値整形。CorrelationBuilder から切り出す。
  module CardText
    module_function

    # 差の大きさをラベル化（因果の強さではなく傾向の目安）。metric の桁で閾値が異なる。
    STRENGTH_THRESHOLDS = { ratio3: 0.05, decimal2: 0.5, per9: 0.5 }.freeze

    def body(spec, diff, is_good)
      formatted = format_diff(spec[:metric_kind], diff)
      verb = diff.positive? ? '高い' : '低い'
      takeaway = is_good ? 'いまの取り組みが効いていそう。この調子で続けよう。' : '少し見直すと変わるかもしれません。'
      "#{spec[:input_label]}が#{spec[:input_more]}週ほど、#{spec[:metric_label]}が#{formatted}#{verb}傾向。#{takeaway}"
    end

    def strength(spec, diff)
      diff.abs >= STRENGTH_THRESHOLDS.fetch(spec[:metric_kind], 0.05) ? 'strong' : 'weak'
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
  end
end
