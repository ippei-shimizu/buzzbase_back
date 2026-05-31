module V2
  # 打球方向マスタ（13方向）。`zone_polygon` を含めて返却することで、
  # mobile クライアントがタップ座標から方向IDを判定できるようにする。
  class HitDirectionSerializer < ActiveModel::Serializer
    attributes :id, :name, :display_order, :zone_polygon
  end
end
