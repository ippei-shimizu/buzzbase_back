# 解約理由アンケートの回答を保存する。
# Flipper :cancellation_survey で有効化されているユーザーからの POST のみを受け取る。
class CancellationFeedback < ApplicationRecord
  belongs_to :user
  belongs_to :subscription, optional: true

  REASONS = %w[expensive less_usage feature_missing competitor other].freeze
  enum reason: REASONS.index_with(&:itself), _prefix: :reason

  validates :reason, presence: true, inclusion: { in: REASONS }
  validates :note, length: { maximum: 1000 }, allow_blank: true
end
