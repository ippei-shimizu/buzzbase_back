module V2
  # 特定日に展開された予定（schedule）を「今日のやること」形式で返す。
  # `done_menu_ids`（その日に練習ログ済みの practice_menu_id 集合）を instance_options で受け取り、
  # メニュー単位・予定単位の「済」判定に使う。
  class PlanSerializer < ActiveModel::Serializer
    attributes :id, :title, :event_type, :scheduled_time, :recurring,
               :menu_set_id, :game_result_id, :note, :menus, :done

    def title
      object.display_title
    end

    def scheduled_time
      object.scheduled_time&.strftime('%H:%M')
    end

    def recurring
      object.recurring?
    end

    def menus
      done_ids = instance_options[:done_menu_ids] || Set.new
      object.resolved_menu_items.map do |item|
        item.merge(done: done_ids.include?(item[:practice_menu_id]))
      end
    end

    # 予定内の全メニューが当日ログ済みなら「済」。メニュー未設定の予定は false。
    def done
      items = menus
      items.any? && items.all? { |item| item[:done] }
    end
  end
end
