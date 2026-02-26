module V2
  # 試合成績(GameResult)のv2シリアライザー（特定ユーザー用）
  #
  # match_result, plate_appearances, batting_average, pitching_result を
  # ネストしたJSONとして1レスポンスに含める。
  # v1では match_result のみ含み、plate_appearances は別APIで取得していた。
  class GameResultSerializer < ActiveModel::Serializer
    attributes :game_result_id

    has_one :match_result, serializer: V2::MatchResultSerializer
    has_many :plate_appearances, serializer: V2::PlateAppearanceSerializer
    has_one :batting_average
    has_one :pitching_result

    # @return [Integer] GameResultのID（フロントエンド側の命名規則に合わせてリネーム）
    def game_result_id
      object.id
    end
  end
end
