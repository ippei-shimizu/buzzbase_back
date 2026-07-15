class BaseballNote < ApplicationRecord
  belongs_to :user
  # モデルA: 試合 or 練習（日次セッション）に緩く紐付く（どちらも任意）。
  belongs_to :practice_log, optional: true
  belongs_to :practice_session, optional: true
  belongs_to :reflection_template, optional: true
  has_many :note_taggings, dependent: :destroy
  has_many :note_tags, through: :note_taggings
  # 試合記録・課題は複数紐付け可（無料は1件・Proは複数、controller側で制限）。
  has_many :note_game_links, dependent: :destroy
  has_many :game_results, through: :note_game_links
  has_many :note_theme_links, dependent: :destroy
  has_many :improvement_themes, through: :note_theme_links

  def extract_and_truncate_memo
    return '' if memo.blank?

    memo_data = JSON.parse(memo)
    texts = memo_data.map { |paragraph| paragraph['children'].pluck('text').join }.join
    texts.truncate(120)
  rescue JSON::ParserError, TypeError, NoMethodError
    # 旧データ・非JSON・想定外構造（children 欠如等）の memo でも一覧表示で落とさない。
    memo.to_s.truncate(120)
  end
end
