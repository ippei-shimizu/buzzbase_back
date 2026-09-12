module V2
  class PracticeMenuSerializer < ActiveModel::Serializer
    attributes :id, :name, :category, :unit, :unit_label, :default_value, :is_favorite, :sort_order
  end
end
