module MatchTypeConvertible
  extend ActiveSupport::Concern

  private

  def convert_match_type(match_type)
    case match_type
    when '公式戦' then 'regular'
    when 'オープン戦' then 'open'
    else match_type
    end
  end

  # 内部表現（regular / open）を画面表示用の日本語ラベル（公式戦 / オープン戦）に戻す。
  # フォームの初期値返却など、モバイル/フロントが直接表示文字列として扱うレスポンスで使用する。
  # @param match_type [String, nil]
  # @return [String, nil] 変換できない値や nil はそのまま返す
  def humanize_match_type(match_type)
    case match_type
    when 'regular' then '公式戦'
    when 'open' then 'オープン戦'
    else match_type
    end
  end
end
