class PracticeSession < ApplicationRecord
  belongs_to :user
  # nullify だと after_commit（草・Streak 再計算）が発火せず集計が古いまま残るため destroy にする。
  has_many :practice_logs, dependent: :destroy
  # ノートは独立した記録なので、セッションを消しても紐付けだけ外して残す。
  has_many :baseball_notes, dependent: :nullify
  # 課題は複数紐付け可（無料は1件・Proは複数、controller/service側で制限）。
  has_many :practice_session_theme_links, dependent: :destroy
  has_many :improvement_themes, through: :practice_session_theme_links

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
  rescue ActiveRecord::RecordNotUnique
    # 同時リクエストで find と create の間に他方が作成した場合は、
    # (user_id, logged_on) のユニークインデックスに任せて拾い直す。
    user.practice_sessions.find_by!(logged_on: date)
  end

  # その日のコンディションログ（1日1件・日付で一意）。
  # practice_session とは別テーブルだが logged_on で 1:1 に対応する。
  def condition_log
    user.condition_logs.find_by(logged_on:)
  end
end
