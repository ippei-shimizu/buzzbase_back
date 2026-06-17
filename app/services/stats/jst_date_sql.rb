# frozen_string_literal: true

module Stats
  # `match_results.date_and_time` は timestamp without time zone で Rails が UTC
  # で書き込むため、PostgreSQL の EXTRACT(YEAR/MONTH FROM ...) を素のまま使うと
  # UTC ベースで月・年が抽出され、JST 元日早朝の試合が前年・前月にバケットされる。
  # 各 stats Aggregator / Service で JST に揃った SQL を組み立てるための共通定数。
  module JstDateSql
    # AT TIME ZONE 'UTC' で unzoned timestamp を timestamptz として解釈し、
    # AT TIME ZONE 'Asia/Tokyo' で JST 表現の timestamp without time zone に戻す。
    DATE_AND_TIME_JST_SQL = "(match_results.date_and_time AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Tokyo'"
    MONTH_JST_INT_SQL = "EXTRACT(MONTH FROM #{DATE_AND_TIME_JST_SQL})::int".freeze
    YEAR_JST_INT_SQL = "EXTRACT(YEAR FROM #{DATE_AND_TIME_JST_SQL})::int".freeze
  end
end
