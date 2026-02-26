module V2
  # 試合成績(GameResult)のv2シリアライザー（全ユーザー用・タイムライン表示向け）
  #
  # GameResultSerializerの内容に加え、ユーザー情報（名前・画像・user_id）を含める。
  # 全ユーザーの試合一覧（タイムライン）で使用する。
  class AllGameResultSerializer < ActiveModel::Serializer
    attributes :game_result_id, :user_id, :user_name, :user_image, :user_user_id

    has_one :match_result, serializer: V2::MatchResultSerializer
    has_many :plate_appearances, serializer: V2::PlateAppearanceSerializer
    has_one :pitching_result

    # @return [Integer] GameResultのID
    def game_result_id
      object.id
    end

    # @return [String] ユーザーの表示名
    def user_name
      object.user.name
    end

    # @return [Object] ユーザーのプロフィール画像（CarrierWaveオブジェクト）
    def user_image
      object.user.image
    end

    # @return [String] ユーザーの公開ID（@表示用）
    def user_user_id
      object.user.user_id
    end
  end
end
