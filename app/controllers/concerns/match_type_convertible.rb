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
end
