module Admin
  module Analytics
    class RetentionSerializer
      class << self
        def serialize(cohort_date, period, retention_rate)
          {
            cohort_date: cohort_date.strftime('%Y/%m/%d'),
            period_days: period,
            retention_rate:,
            analysis_date: (cohort_date + period.days).strftime('%Y/%m/%d'),
            description: "#{cohort_date.strftime('%Y/%m/%d')}登録ユーザーの#{period}日後継続率"
          }
        end
      end
    end
  end
end
