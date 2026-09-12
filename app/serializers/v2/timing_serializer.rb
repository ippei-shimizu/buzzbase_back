module V2
  class TimingSerializer < ActiveModel::Serializer
    attributes :id, :name, :display_order
  end
end
