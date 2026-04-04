# frozen_string_literal: true

module Stats
  module Concerns
    module TableServiceConcern
      extend ActiveSupport::Concern

      ZERO = 0

      private

      def scope_for_year(scope, year)
        scope.where('match_results.date_and_time >= ? AND match_results.date_and_time < ?',
                    "#{year}-01-01 00:00:00", "#{year + 1}-01-01 00:00:00")
      end

      def scope_for_month(scope, mon)
        if @year.present?
          year = @year.to_i
          next_month = mon == 12 ? 1 : mon + 1
          next_year = mon == 12 ? year + 1 : year
          scope.where('match_results.date_and_time >= ? AND match_results.date_and_time < ?',
                      "#{year}-#{format('%02d', mon)}-01 00:00:00",
                      "#{next_year}-#{format('%02d', next_month)}-01 00:00:00")
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
