module V2
  class ScheduleSerializer < ActiveModel::Serializer
    attributes :id, :title, :days_of_week, :planned_on, :scheduled_time, :event_type,
               :recurring, :menu_set_id, :game_result_id, :note,
               :notification_enabled, :active, :notification_message, :menus,
               :logged_practice_menu_ids

    def title
      object.display_title
    end

    # カスタム通知文は Pro 限定。解約しても DB には過去に設定した値が残るため、
    # 保存値ではなく参照時点の entitlement で出し分ける（無料なら端末側の既定文が使われる）。
    def notification_message
      custom_messages_allowed? ? object.notification_message : nil
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

    # この予定に対して過去に練習ログが記録済みの practice_menu_id 一覧。
    # 編集画面でこの予定のメニューを変更してしまうと済判定が壊れるため、
    # 該当メニューを編集不可にする目印としてクライアントへ返す。
    def logged_practice_menu_ids
      object.practice_logs.filter_map(&:practice_menu_id).uniq
    end

    private

    # 判定結果は同一ユーザーなら同じなので、一覧系は instance_options で 1 回だけ
    # 解決した値を渡して N+1 を避ける。渡されなかった場合はレコードの所有者から引く
    # （呼び出し側の渡し忘れで Pro ユーザーの通知文が消えないようにするため）。
    def custom_messages_allowed?
      return instance_options[:custom_notification_messages] if instance_options.key?(:custom_notification_messages)

      object.user.has_entitlement?('custom_notification_messages')
    end
  end
end
