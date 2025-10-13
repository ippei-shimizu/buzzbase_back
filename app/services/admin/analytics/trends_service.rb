module Admin
  module Analytics
    class TrendsService
      def initialize(start_date, end_date)
        @start_date = start_date
        @end_date = end_date
      end

      def call
        Admin::Analytics::TrendsSerializer.serialize(daily_stats, content_breakdown)
      end

      private

      def daily_stats
        @daily_stats ||= Admin::DailyStatistic.by_date_range(@start_date, @end_date)
      end

      def content_breakdown
        @content_breakdown ||= {
          games: GameResult.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day).count,
          batting_records: BattingAverage.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day).count,
          pitching_records: PitchingResult.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day).count
        }
      end
    end
  end
end
