module V2
  class MenuSetSerializer < ActiveModel::Serializer
    attributes :id, :name, :note, :sort_order, :items

    # セット内メニューを表示用に整形して返す。
    def items
      object.menu_set_items.map do |item|
        {
          practice_menu_id: item.practice_menu_id,
          name: item.practice_menu&.name,
          unit_label: item.practice_menu&.unit_label,
          target_value: item.target_value
        }
      end
    end
  end
end
