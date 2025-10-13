module Admin
  module Analytics
    class FeaturesService
      def initialize(start_date, end_date)
        @start_date = start_date
        @end_date = end_date
      end

      def call
        {
          content_usage: calculate_content_usage,
          game_types: calculate_game_types,
          post_types: calculate_post_types
        }
      end

      private

      def calculate_content_usage
        content_counts = {
          games: GameResult.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day).count,
          batting_records: BattingAverage.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day).count,
          pitching_records: PitchingResult.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day).count
        }

        total_content = content_counts.values.sum
        return {} if total_content.zero?

        content_counts.transform_values do |count|
          {
            count:,
            percentage: ((count.to_f / total_content) * 100).round(2)
          }
        end
      end

      def calculate_game_types
        GameResult.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
                  .group(:game_type)
                  .count
      end

      def calculate_post_types
        {
          batting_averages: BattingAverage.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day).count,
          pitching_results: PitchingResult.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day).count,
          baseball_notes: BaseballNote.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day).count
        }
      end
    end
  end
end
