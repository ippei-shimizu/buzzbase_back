class Season < ApplicationRecord
  belongs_to :user
  has_many :game_results, dependent: :nullify
  # シーズン目標は season_id が外れると集計期間を失うため、進行中のものが残っている間は削除を止める。
  has_many :goals, dependent: :nullify

  validates :name, presence: true, length: { maximum: 50 }, uniqueness: { scope: :user_id }

  before_validation :normalize_name

  # dependent: :nullify も before_destroy として登録されるため、prepend で必ずガードを先に走らせる。
  before_destroy :guard_against_active_season_goals, prepend: true

  # 検索キーと保存値がズレると既存を取り逃して重複 INSERT になるため、正規化はここに一本化する。
  # String#strip は全角スペースを落とさないので squish を使う。
  # @param value [String, nil]
  # @return [String]
  def self.normalize_name(value)
    value.to_s.squish
  end

  # 同名シーズンがあれば作成せず既存を返す冪等な解決。
  # 手入力で既存と同名になっても呼び出し元の処理を落とさないために使う。
  # @param user [User]
  # @param name [String]
  # @return [Season] 保存済みレコード
  def self.find_or_create_for!(user, name)
    normalized = normalize_name(name)
    existing = user.seasons.find_by(name: normalized)
    return existing if existing

    # 一意制約違反は外側トランザクションごと abort させ復旧クエリまで道連れにするため、
    # セーブポイント内で INSERT して影響をここに閉じ込める。
    ActiveRecord::Base.transaction(requires_new: true) { user.seasons.create!(name: normalized) }
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    # 相手のコミットが一意性バリデーションの SELECT より前なら RecordInvalid、後なら RecordNotUnique。
    # 引き直せないなら name 以外の検証エラーなので握り潰さず投げ直す。
    user.seasons.find_by(name: normalized) || raise(e)
  end

  private

  def normalize_name
    self.name = self.class.normalize_name(name)
  end

  def guard_against_active_season_goals
    return unless goals.exists?(period_type: 'season', is_finalized: false)

    errors.add(:base, '進行中のシーズン目標が紐づいているため削除できません')
    throw(:abort)
  end
end
