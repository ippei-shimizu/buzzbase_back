module V2
  class ScheduleSerializer < ActiveModel::Serializer
    attributes :id, :title, :days_of_week, :scheduled_time, :note,
               :notification_enabled, :active, :notification_message, :menus

    def scheduled_time
      object.scheduled_time&.strftime('%H:%M')
    end

    # 紐付いた練習メニューを表示用に整形して返す。
    def menus
      object.schedule_menus.map do |schedule_menu|
        {
          practice_menu_id: schedule_menu.practice_menu_id,
          name: schedule_menu.practice_menu&.name,
          unit_label: schedule_menu.practice_menu&.unit_label,
          target_value: schedule_menu.target_value
        }
      end
    end
  end
end
