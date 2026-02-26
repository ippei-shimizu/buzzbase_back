module V2
  # 打席結果(PlateAppearance)のv2シリアライザー
  #
  # v1ではフロントエンドが試合ごとに個別APIで打席結果を取得していた（N+1 HTTPリクエスト）。
  # v2ではGameResultSerializer経由でhas_manyとして一括返却する。
  class PlateAppearanceSerializer < ActiveModel::Serializer
    attributes :id, :batter_box_number, :batting_result, :game_result_id
  end
end
