# frozen_string_literal: true

module Stats
  module Concerns
    module TableServiceConcern
      extend ActiveSupport::Concern

      ZERO = 0

      private

      def scope_for_year(scope, year)
        scope.where('match_results.date_and_time >= ? AND match_results.date_and_time <= ?',
                    "#{year}-01-01 00:00:00", "#{year}-12-31 23:59:59")
      end

      def scope_for_month(scope, mon)
        if @year.present?
          year = @year.to_i
          last_day = Date.new(year, mon, -1).day
          scope.where('match_results.date_and_time >= ? AND match_results.date_and_time <= ?',
                      "#{year}-#{format('%02d', mon)}-01 00:00:00",
                      "#{year}-#{format('%02d', mon)}-#{format('%02d', last_day)} 23:59:59")
        else
          scope.where('EXTRACT(MONTH FROM match_results.date_and_time) = ?', mon)
        end
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
