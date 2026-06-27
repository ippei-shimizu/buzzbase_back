class BaseballNote < ApplicationRecord
  belongs_to :user
  # モデルA: 試合 or 練習（日次セッション）に緩く紐付く（どちらも任意）。
  belongs_to :game_result, optional: true
  belongs_to :practice_log, optional: true
  belongs_to :practice_session, optional: true

  def extract_and_truncate_memo
    return '' if memo.blank?

    memo_data = JSON.parse(memo)
    texts = memo_data.map { |paragraph| paragraph['children'].pluck('text').join }.join
    texts.truncate(120)
  rescue JSON::ParserError
    # 旧データや非JSONの memo でも一覧表示で落とさない。
    memo.to_s.truncate(120)
  end
end
