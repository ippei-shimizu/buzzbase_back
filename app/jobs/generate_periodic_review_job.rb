class GeneratePeriodicReviewJob < ApplicationJob
  queue_as :default

  JST = 'Asia/Tokyo'.freeze

  # 直前に締まった期間の振り返りレポートを生成する。
  # 週次は全ユーザー、月次は Pro ユーザーのみ（月次レポートは Pro 限定機能のため）。
  # @param period_type [String] 'weekly' / 'monthly'
  def perform(period_type)
    period_start = period_start_for(period_type)
    User.active.find_each do |user|
      next if period_type == 'monthly' && !user.has_entitlement?('advanced_periodic_review')

      PeriodicReviews::Generator.new(user:, period_type:, period_start:).call
    end
  end

  private

  # 直前に終了した週（前週の月曜）/ 月（前月の1日）の開始日。
  def period_start_for(period_type)
    today = Time.find_zone(JST).today
    period_type == 'monthly' ? today.prev_month.beginning_of_month : today.beginning_of_week - 7
  end
end
