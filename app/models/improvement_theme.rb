class ImprovementTheme < ApplicationRecord
  belongs_to :user
  has_many :practice_sessions, dependent: :nullify
  has_many :baseball_notes, dependent: :nullify

  # open: 取組中 / achieved: 克服(達成) / archived: 取りやめ
  enum status: { open: 'open', achieved: 'achieved', archived: 'archived' }, _default: 'open'

  CATEGORIES = %w[batting pitching defense baserunning training strength care other].freeze

  validates :title, presence: true, length: { maximum: 100 }
  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validates :started_on, presence: true

  before_validation :set_started_on, on: :create

  scope :ordered, -> { order(sort_order: :asc, created_at: :desc) }

  # 課題を克服（達成）扱いにする。達成日を記録する。
  # @param on [Date] 達成日（既定は JST の当日）
  def achieve!(on: Time.find_zone('Asia/Tokyo').today)
    update!(status: 'achieved', achieved_on: on)
  end

  # この課題に紐付く練習ログ件数。
  # @return [Integer]
  def practice_logs_count
    PracticeLog.where(practice_session_id: practice_sessions.select(:id)).count
  end

  # この課題に紐付くノート件数。
  # @return [Integer]
  def notes_count
    baseball_notes.count
  end

  # この課題に取り組んだ日数（練習セッションのある distinct 日数）。
  # @return [Integer]
  def active_days
    practice_sessions.distinct.count(:logged_on)
  end

  private

  def set_started_on
    self.started_on ||= Time.find_zone('Asia/Tokyo').today
  end
end
