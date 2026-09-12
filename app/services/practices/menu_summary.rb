module Practices
  # ユーザーの練習ログをメニュー単位で集計し、積み上げサマリーを返す。
  # 単位混在を避けるためメニュー単位で集計する。改名済みは practice_menu の最新名、
  # 削除済み（menu nil）は menu_name スナップショットで束ねる。
  class MenuSummary
    JST = 'Asia/Tokyo'.freeze

    def initialize(user)
      @user = user
    end

    # @return [Array<Hash>] 直近に記録した（created_at が新しい）メニュー順
    def call
      month_start = Time.find_zone(JST).today.beginning_of_month
      @user.practice_logs.includes(:practice_menu).to_a
           .group_by { |log| log.practice_menu_id || "name:#{log.menu_name}" }
           .values
           .sort_by { |group| group.map(&:created_at).max }
           .reverse
           .map { |group| summarize(group, month_start) }
    end

    private

    def summarize(group, month_start)
      menu = group.first.practice_menu
      unit = menu&.unit || 'count'
      weight_reps = weight_reps?(group, unit)
      month = group.select { |log| log.logged_on >= month_start }

      {
        practice_menu_id: menu&.id,
        menu_name: name_of(group, menu),
        unit:,
        unit_label: unit_label_of(group, menu),
        total_amount: sum_amount(group),
        total_volume: volume_of(group, weight_reps),
        this_month_amount: sum_amount(month),
        this_month_volume: volume_of(month, weight_reps),
        days_count: group.map(&:logged_on).uniq.size,
        last_logged_on: group.map(&:logged_on).max&.to_s
      }
    end

    def weight_reps?(group, unit)
      unit == 'weight_reps' || group.any? { |log| log.weight.present? }
    end

    def name_of(group, menu)
      menu ? menu.name : group.first.menu_name
    end

    def unit_label_of(group, menu)
      menu ? menu.unit_label : group.first.unit_label
    end

    def volume_of(logs, weight_reps)
      weight_reps ? sum_volume(logs) : nil
    end

    def sum_amount(logs)
      logs.sum { |log| log.amount.to_f }
    end

    def sum_volume(logs)
      logs.sum { |log| log.amount.to_f * log.weight.to_f }
    end
  end
end
