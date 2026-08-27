class Tournament < ApplicationRecord
  # NOTE: 同名重複を後から統合する際は、先に match_results.tournament_id を残す側へ付け替えること。
  # dependent: :destroy のため destroy で消すとユーザーの試合記録ごと失われる。
  has_many :match_results, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }

  before_validation :normalize_name

  # 検索キーと保存値がズレると既存を取り逃して重複レコードを作るため、正規化はここに一本化する。
  # String#strip は全角スペースを落とさないので squish を使う。
  # @param value [String, nil]
  # @return [String]
  def self.normalize_name(value)
    value.to_s.squish
  end

  # 同名の大会があれば既存を、無ければ未保存の新規インスタンスを返す。
  # 既存の同名重複が残っている間、LIMIT 1 の返却行がプランに依存してブレないよう id 昇順で固定する。
  # @param name [String]
  # @return [Tournament]
  def self.find_or_initialize_by_name(name)
    normalized = normalize_name(name)
    where(name: normalized).order(:id).first || new(name: normalized)
  end

  private

  def normalize_name
    self.name = self.class.normalize_name(name)
  end
end
