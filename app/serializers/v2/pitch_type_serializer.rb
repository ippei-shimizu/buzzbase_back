module V2
  class PitchTypeSerializer < ActiveModel::Serializer
    attributes :id, :name, :display_order
  end
end
