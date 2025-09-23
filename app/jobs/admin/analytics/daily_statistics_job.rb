module Admin
  module Analytics
    class DailyStatisticsJob < ApplicationJob
      queue_as :default

      def perform(target_date = Date.current - 1.day)
        Rails.logger.info "Starting daily statistics calculation for #{target_date}"

        begin
          daily_stat = Admin::DailyStatistic.calculate_for_date(target_date)

          Rails.logger.info "Daily statistics calculation completed for #{target_date}"
          Rails.logger.info "Stats: Users=#{daily_stat.total_users}, DAU=#{daily_stat.active_users}, New=#{daily_stat.new_users}"

          { success: true, date: target_date, stats: daily_stat }
        rescue StandardError => e
          Rails.logger.error "Daily statistics calculation failed for #{target_date}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")

          raise e
        end
      end

      def self.perform_batch(start_date, end_date)
        Rails.logger.info "Starting batch daily statistics calculation from #{start_date} to #{end_date}"

        results = []
        errors = []

        (start_date..end_date).each do |date|
          job_result = new.perform(date)
          results << job_result
        rescue StandardError => e
          error_info = { date:, error: e.message }
          errors << error_info
          Rails.logger.error "Failed to calculate stats for #{date}: #{e.message}"
        end

        Rails.logger.info "Batch calculation completed. Success: #{results.count}, Errors: #{errors.count}"

        {
          success_count: results.count,
          error_count: errors.count,
          results:,
          errors:
        }
      end

      def self.backfill_missing_data(days_back = 30)
        end_date = Date.current - 1.day
        start_date = end_date - days_back.days

        existing_dates = Admin::DailyStatistic.where(date: start_date..end_date).pluck(:date)
        missing_dates = (start_date..end_date).to_a - existing_dates

        if missing_dates.empty?
          Rails.logger.info 'No missing daily statistics data found'
          return { missing_count: 0, backfilled: [] }
        end

        Rails.logger.info "Found #{missing_dates.count} missing dates. Starting backfill..."

        backfilled = []
        missing_dates.each do |date|
          new.perform(date)
          backfilled << date
          Rails.logger.info "Backfilled data for #{date}"
        rescue StandardError => e
          Rails.logger.error "Failed to backfill data for #{date}: #{e.message}"
        end

        Rails.logger.info "Backfill completed. Processed: #{backfilled.count}/#{missing_dates.count}"

        {
          missing_count: missing_dates.count,
          backfilled:,
          failed: missing_dates - backfilled
        }
      end
    end
  end
end
