# frozen_string_literal: true

# 試合日時 (match_results.date_and_time) を年月レンジ ("YYYY-MM") で絞り込む共通ヘルパー。
# 下限含む・上限排他（終了月の翌月1日 0:00 未満）で扱い、既存 year フィルタと datetime 境界を統一する。
# 呼び出し側の scope は match_results を join 済みである前提。start/end いずれか一方のみでも可（開放端）。
module PeriodRange
  module_function

  # @param scope [ActiveRecord::Relation] match_results を join 済みの scope
  # @param start_month [String, nil] "YYYY-MM"。開始月の1日 0:00 以降を含む。未指定・不正は下限なし
  # @param end_month [String, nil] "YYYY-MM"。終了月の末日までを含む。未指定・不正は上限なし
  # @return [ActiveRecord::Relation] レンジ条件を適用した scope
  def apply(scope, start_month, end_month)
    range_start, range_end = bounds(start_month, end_month)
    scope = scope.where('match_results.date_and_time >= ?', range_start) if range_start
    scope = scope.where('match_results.date_and_time < ?', range_end) if range_end
    scope
  end

  # hash 条件（where(match_results: { date_and_time: ... })）に渡す Range を返す。
  # 上限は排他。両端とも不正・未指定なら nil。raw SQL join が張られていない
  # includes ベースの scope でも auto-reference が効くよう、hash 条件用に使う。
  def range(start_month, end_month)
    range_start, range_end = bounds(start_month, end_month)
    return nil unless range_start || range_end

    Range.new(range_start, range_end, true)
  end

  # 開始/終了から [下限(含む), 上限(排他)] を返す。開始 > 終了 の逆転レンジは
  # 入れ替えて正規化し、「静かに0件」になる混乱を防ぐ（フロントのクランプが外れた場合の保険）。
  def bounds(start_month, end_month)
    range_start = parse_start(start_month)
    range_end = parse_end_exclusive(end_month)
    return [parse_start(end_month), parse_end_exclusive(start_month)] if range_start && range_end && range_start >= range_end

    [range_start, range_end]
  end

  def parse_start(month)
    year, mon = parse(month)
    return nil unless year

    Time.zone.local(year, mon, 1)
  end

  def parse_end_exclusive(month)
    year, mon = parse(month)
    return nil unless year

    next_month = mon == 12 ? 1 : mon + 1
    next_year = mon == 12 ? year + 1 : year
    Time.zone.local(next_year, next_month, 1)
  end

  # "YYYY-MM" を [year, month] に分解する。不正フォーマット・範囲外の月は [nil, nil]。
  def parse(month)
    return [nil, nil] if month.blank?

    matched = month.to_s.match(/\A(\d{4})-(\d{1,2})\z/)
    return [nil, nil] unless matched

    mon = matched[2].to_i
    return [nil, nil] unless mon.between?(1, 12)

    [matched[1].to_i, mon]
  end
end
