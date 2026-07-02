module V2
  # 課題（テーマ）。取組状況の集計値（練習・ノート件数、取組日数）を同梱する。
  class ImprovementThemeSerializer < ActiveModel::Serializer
    attributes :id, :title, :category, :purpose, :status, :started_on, :achieved_on,
               :sort_order, :practice_logs_count, :notes_count, :active_days, :created_at

    delegate :practice_logs_count, to: :object

    delegate :notes_count, to: :object

    delegate :active_days, to: :object
  end
end
