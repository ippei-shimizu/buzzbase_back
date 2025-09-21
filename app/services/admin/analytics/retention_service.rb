module Admin
  module Analytics
    class RetentionService
      def initialize(cohort_date, period)
        @cohort_date = cohort_date
        @period = period
        @stats_factory = Admin::Analytics::StatsFactory
      end

      def call
        retention_rate = Admin::DailyStatistic.retention_rate(@cohort_date, @period)
        @stats_factory.build_retention_data(@cohort_date, @period, retention_rate)
      end
    end
  end
end
