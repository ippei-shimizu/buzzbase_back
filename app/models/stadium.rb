class Stadium < ApplicationRecord
  belongs_to :prefecture, optional: true
  belongs_to :created_by_user, class_name: 'User', optional: true
  has_many :match_results, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
  # 同一都道府県内での同名球場を防ぐ。prefecture_id が NULL の場合は重複を許容する（県不明データ向け）。
  validates :name, uniqueness: { scope: :prefecture_id, case_sensitive: false }, if: -> { prefecture_id.present? }

  before_validation :normalize_name

  # 検索キーと保存値がズレると既存を取り逃して重複レコードを作るため、正規化はここに一本化する。
  # String#strip は全角スペースを落とさないので squish を使う。
  # @param value [String, nil]
  # @return [String]
  def self.normalize_name(value)
    value.to_s.squish
  end

  # 同一都道府県内に同名の球場があれば作成せず既存を返す冪等な解決。
  #
  # prefecture_id が nil のリクエストは nil 同士だけで名寄せする。「市民球場」のような県跨ぎの
  # 同名が多く、県不明の入力を県付きレコードへ繋ぐと別の球場に紐付いてしまうため。
  # @param name [String]
  # @param prefecture_id [Integer, nil]
  # @param created_by_user [User, nil] 新規作成時のみ記録する作成者
  # @return [Stadium] 保存済みレコード
  def self.find_or_create_for!(name:, prefecture_id:, created_by_user: nil)
    normalized = normalize_name(name)
    existing = find_by_normalized_name(normalized, prefecture_id)
    return existing if existing

    # prefecture_id 付きには部分ユニークインデックスがあり、同時実行で INSERT が負けうる。
    # 制約違反は外側トランザクションごと abort させ復旧クエリまで道連れにするため、
    # セーブポイント内で INSERT して影響をここに閉じ込める。
    ActiveRecord::Base.transaction(requires_new: true) do
      create!(name: normalized, prefecture_id:, created_by_user:)
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    # 相手のコミットが一意性バリデーションの SELECT より前なら RecordInvalid、後なら RecordNotUnique。
    # 引き直せないなら name 以外の検証エラーなので握り潰さず投げ直す。
    find_by_normalized_name(normalized, prefecture_id) || raise(e)
  end

  # 一意性バリデーションが case_sensitive: false なので検索側も LOWER 比較で揃える。
  # ズレると大文字小文字違いの同名を取り逃して一意性違反になる。
  def self.find_by_normalized_name(normalized, prefecture_id)
    where(prefecture_id:).where('LOWER(name) = LOWER(?)', normalized).order(:id).first
  end
  private_class_method :find_by_normalized_name

  private

  def normalize_name
    self.name = self.class.normalize_name(name)
  end
end
