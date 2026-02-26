module V2
  # 試合結果(MatchResult)のv2シリアライザー
  #
  # v1では opponent_team_id / tournament_id のみ返却し、
  # フロントエンドが個別にチーム名・大会名APIを叩いていた（N+1 HTTPリクエスト）。
  # v2では opponent_team_name / tournament_name を展開して返却することで、
  # フロントエンドの追加リクエストを不要にする。
  class MatchResultSerializer < ActiveModel::Serializer
    attributes :id, :date_and_time, :match_type, :my_team_id, :opponent_team_id,
               :my_team_score, :opponent_team_score, :batting_order,
               :defensive_position, :tournament_id, :memo,
               :opponent_team_name, :tournament_name

    # @return [String, nil] 対戦相手チーム名（eager-load済み）
    def opponent_team_name
      object.opponent_team&.name
    end

    # @return [String, nil] 大会名（eager-load済み）
    def tournament_name
      object.tournament&.name
    end
  end
end
