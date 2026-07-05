module V2
  class ScheduleSerializer < ActiveModel::Serializer
    attributes :id, :title, :days_of_week, :planned_on, :scheduled_time, :event_type,
               :recurring, :menu_set_id, :game_result_id, :note,
               :notification_enabled, :active, :notification_message, :menus

    def title
      object.display_title
    end

    def scheduled_time
      object.scheduled_time&.strftime('%H:%M')
    end

    def recurring
      object.recurring?
    end

    # 紐付いた練習メニューを表示用に整形して返す。
    # メニューセット指定時はセット内メニュー、無ければ個別紐付け（schedule_menus）を展開する。
    def menus
      object.resolved_menu_items.map do |item|
        item.slice(:practice_menu_id, :name, :unit_label, :target_value)
      end
    end
  end
end
