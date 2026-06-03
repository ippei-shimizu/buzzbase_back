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
               :defensive_position, :tournament_id, :memo, :inning_format,
               :appearance_type, :stadium_id,
               :my_team_name, :opponent_team_name, :tournament_name, :stadium_name

    # @return [String, nil] 自チーム名（eager-load済み）
    def my_team_name
      object.my_team&.name
    end

    # @return [String, nil] 対戦相手チーム名（eager-load済み）
    def opponent_team_name
      object.opponent_team&.name
    end

    # @return [String, nil] 大会名（eager-load済み）
    def tournament_name
      object.tournament&.name
    end

    # @return [String, nil] 球場名（eager-load済み、未設定時は nil）
    def stadium_name
      object.stadium&.name
    end
  end
end
