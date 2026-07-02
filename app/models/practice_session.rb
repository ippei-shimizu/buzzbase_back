class PracticeSession < ApplicationRecord
  belongs_to :user
  belongs_to :improvement_theme, optional: true
  has_many :practice_logs, dependent: :nullify
  has_many :baseball_notes, dependent: :nullify

  validates :logged_on, presence: true
  validates :user_id, uniqueness: { scope: :logged_on }

  scope :ordered, -> { order(logged_on: :desc) }

  # 指定ユーザー・日付の日次セッションを取得（無ければ作成）。
  # 練習ログ作成時に当日のセッションへ自動でぶら下げるために使う。
  #
  # @param user [User]
  # @param date [Date, String]
  # @return [PracticeSession]
  def self.for(user, date)
    user.practice_sessions.find_or_create_by!(logged_on: date)
  end

  # その日のコンディションログ（1日1件・日付で一意）。
  # practice_session とは別テーブルだが logged_on で 1:1 に対応する。
  def condition_log
    user.condition_logs.find_by(logged_on:)
  end
end
