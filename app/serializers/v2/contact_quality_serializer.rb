module V2
  class ContactQualitySerializer < ActiveModel::Serializer
    attributes :id, :name, :display_order
  end
end
