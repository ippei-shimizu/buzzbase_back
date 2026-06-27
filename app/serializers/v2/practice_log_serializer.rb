module V2
  class PracticeLogSerializer < ActiveModel::Serializer
    attributes :id, :practice_menu_id, :logged_on, :amount, :menu_name, :unit_label, :source, :memo, :created_at
  end
end
