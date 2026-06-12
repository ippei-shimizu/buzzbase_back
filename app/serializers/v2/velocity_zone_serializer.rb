module V2
  class VelocityZoneSerializer < ActiveModel::Serializer
    attributes :id, :name, :display_order
  end
end
