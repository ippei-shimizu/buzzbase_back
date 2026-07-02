module V2
  # 振り返りテンプレ。運営プリセット（is_preset）とユーザー自作を同じ形で返す。
  class ReflectionTemplateSerializer < ActiveModel::Serializer
    attributes :id, :title, :questions, :is_preset, :is_default, :sort_order
  end
end
