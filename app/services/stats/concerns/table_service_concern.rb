# frozen_string_literal: true

module Stats
  module Concerns
    module TableServiceConcern
      extend ActiveSupport::Concern

      ZERO = 0

      private

      def scope_for_year(scope, year)
        range_start = Time.zone.local(year, 1, 1)
        range_end = Time.zone.local(year + 1, 1, 1)
        scope.where('match_results.date_and_time >= ? AND match_results.date_and_time < ?',
                    range_start, range_end)
      end

      def scope_for_month(scope, mon)
        if @year.present?
          year = @year.to_i
          next_month = mon == 12 ? 1 : mon + 1
          next_year = mon == 12 ? year + 1 : year
          range_start = Time.zone.local(year, mon, 1)
          range_end = Time.zone.local(next_year, next_month, 1)
          scope.where('match_results.date_and_time >= ? AND match_results.date_and_time < ?',
                      range_start, range_end)
        else
          scope.where("#{Stats::JstDateSql::MONTH_JST_INT_SQL} = ?", mon)
        end
      end

      # monthly テーブルの各行（ラベルと scope）の組を返す。
      # 期間フィルタで年をまたぐ場合は「同じ月番号が別の年で重複」しうるため、
      # 年月粒度（"YYYY/M月"）で分割する。単年・通算では従来どおり月粒度（"M月"）。
      # @param scope [ActiveRecord::Relation] 集計対象（年フィルタ/期間フィルタ適用済み）
      # @return [Array<Array(String, ActiveRecord::Relation)>] [ラベル, その月の scope] の配列
      def monthly_buckets(scope)
        return year_month_buckets(scope) if @start_month.present? || @end_month.present?

        month_buckets(scope)
      end

      def month_buckets(scope)
        months = scope.select(Arel.sql("DISTINCT #{Stats::JstDateSql::MONTH_JST_INT_SQL} AS mon"))
                      .filter_map(&:mon).sort
        months.map { |month| ["#{month}月", scope_for_month(scope, month)] }
      end

      def year_month_buckets(scope)
        pairs = scope
                .select(Arel.sql("DISTINCT #{Stats::JstDateSql::YEAR_JST_INT_SQL} AS yr, #{Stats::JstDateSql::MONTH_JST_INT_SQL} AS mon"))
                .filter_map { |row| row.yr && row.mon ? [row.yr, row.mon] : nil }
                .sort
        multi_year = pairs.map(&:first).uniq.size > 1
        pairs.map do |year, month|
          label = multi_year ? "#{year}/#{month}月" : "#{month}月"
          [label, scope_for_year_month(scope, year, month)]
        end
      end

      def scope_for_year_month(scope, year, month)
        next_month = month == 12 ? 1 : month + 1
        next_year = month == 12 ? year + 1 : year
        scope.where('match_results.date_and_time >= ? AND match_results.date_and_time < ?',
                    Time.zone.local(year, month, 1), Time.zone.local(next_year, next_month, 1))
      end

      def safe_divide(numerator, denominator, precision = 3)
        denominator.zero? ? ZERO : (numerator / denominator).round(precision)
      end

      # Extract integer stats from an object using a list of attribute names
      def extract_int_stats(record, fields)
        fields.index_with { |f| record.public_send(f).to_i }
      end

      # Convert string-keyed hash values to integers for given keys
      def int_values(hash, keys)
        keys.index_with { |k| hash[k].to_i }
      end
    end
  end
end
