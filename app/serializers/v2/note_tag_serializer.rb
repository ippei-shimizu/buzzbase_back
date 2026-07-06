module V2
  class NoteTagSerializer < ActiveModel::Serializer
    attributes :id, :name, :is_preset
  end
end
