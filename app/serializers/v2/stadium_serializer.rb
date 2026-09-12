module V2
  class StadiumSerializer < ActiveModel::Serializer
    attributes :id, :name

    has_one :prefecture, serializer: V2::PrefectureSerializer
  end
end
