module V2
  # 投手マスタのレスポンス。所属チーム + 3 つの属性マスタを nested で返す。
  # `created_by_user_id` はクライアントに露出しない（ユーザー固有マスタの整合性は
  # サーバ側のクエリで担保するため、フロントには持たせない）。
  class PitcherSerializer < ActiveModel::Serializer
    attributes :id, :name, :throw_hand, :team_id, :memo

    has_one :arm_angle, serializer: V2::ArmAngleSerializer
    has_one :velocity_zone, serializer: V2::VelocityZoneSerializer
    has_one :pitcher_style, serializer: V2::PitcherStyleSerializer
  end
end
