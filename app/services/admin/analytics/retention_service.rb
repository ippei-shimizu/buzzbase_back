module Admin
  module Analytics
    class RetentionService
      def initialize(cohort_date, period)
        @cohort_date = cohort_date
        @period = period
      end

      def call
        retention_rate = Admin::DailyStatistic.retention_rate(@cohort_date, @period)
        Admin::Analytics::RetentionSerializer.serialize(@cohort_date, @period, retention_rate)
      end
    end
  end
end
