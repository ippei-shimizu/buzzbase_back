class PracticeSession < ApplicationRecord
  PRACTICE_TYPES = %w[self_practice team_practice].freeze

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
  validates :practice_type, inclusion: { in: PRACTICE_TYPES }

  scope :ordered, -> { order(logged_on: :desc) }

  # 指定ユーザー・日付の日次セッションを取得（無ければ作成）。
  # 練習ログ作成時に当日のセッションへ自動でぶら下げるために使う。
  #
  # @param user [User]
  # @param date [Date, String]
  # @param practice_type [String, nil] 新規作成時のみ反映する練習種別（nil ならカラム既定値）
  # @return [PracticeSession]
  def self.for(user, date, practice_type: nil)
    existing = user.practice_sessions.find_by(logged_on: date)
    return existing if existing

    # PracticeSessions::Upsert のような外側トランザクション内から呼ばれると、
    # ユニーク制約違反がトランザクション全体を abort させて rescue 節の復旧クエリまで
    # 道連れになる。セーブポイント内で INSERT させて影響をここに閉じ込める。
    ActiveRecord::Base.transaction(requires_new: true) do
      user.practice_sessions.create!({ logged_on: date, practice_type: }.compact)
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    # 同時リクエストで find_by と INSERT の間に他方が作成した場合の復旧。
    # 相手方のコミットが一意性バリデーションの SELECT より前なら RecordInvalid、
    # 後なら DB のユニークインデックス違反（RecordNotUnique）になるため両方から拾い直す。
    # 行が見つからないなら別要因の検証エラーなので握り潰さず投げ直す。
    user.practice_sessions.find_by(logged_on: date) || raise(e)
  end

  # その日のコンディションログ（1日1件・日付で一意）。
  # practice_session とは別テーブルだが logged_on で 1:1 に対応する。
  def condition_log
    user.condition_logs.find_by(logged_on:)
  end
end
