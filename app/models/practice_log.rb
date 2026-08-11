class PracticeLog < ApplicationRecord
  belongs_to :user
  belongs_to :practice_menu, optional: true
  belongs_to :practice_session, optional: true
  belongs_to :schedule, optional: true

  SOURCES = %w[manual shadow_swing].freeze

  validates :logged_on, presence: true
  validates :menu_name, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weight, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # 単票でログを作っても当日の日次セッションへ束ねる（お気に入りワンタップ・素振り自動ログ含む）。
  before_validation :assign_practice_session, on: :create

  # 練習ログの変化で当日の活動集計（草・Streak）を再計算する。
  after_commit :recalculate_activity, on: %i[create update destroy]

  private

  def assign_practice_session
    return if practice_session_id.present? || logged_on.blank?

    self.practice_session = PracticeSession.for(user, logged_on, practice_type: inferred_practice_type)
  end

  # 予定チェックから生まれたログは、その予定の種別でその日をチーム練習として起こす。
  # nil を返した場合はカラム既定値（self_practice）に委ねる。
  def inferred_practice_type
    return nil if schedule.nil?

    %w[practice game].include?(schedule.event_type) ? 'team_practice' : nil
  end

  def recalculate_activity
    Activities::DailyActivityRecalculator.new(user_id:, date: logged_on).call
  end
end
