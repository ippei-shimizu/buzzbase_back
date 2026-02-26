class GameResult < ApplicationRecord
  belongs_to :user
  has_one :match_result, dependent: :destroy
  has_many :plate_appearances, dependent: :destroy
  has_one :batting_average, dependent: :destroy
  has_one :pitching_result, dependent: :destroy

  def self.all_game_associated_data
    includes(:user, :match_result, :plate_appearances, :pitching_result)
      .where.not(match_result_id: nil)
      .joins(:match_result)
      .order('match_results.date_and_time DESC')
      .map do |game_result|
        {
          game_result_id: game_result.id,
          user_id: game_result.user_id,
          user_name: game_result.user.name,
          user_image: game_result.user.image,
          user_user_id: game_result.user.user_id,
          match_result: game_result.match_result,
          plate_appearances: game_result.plate_appearances,
          pitching_result: game_result.pitching_result
        }
      end
  end

  def self.game_associated_data_user(user)
    includes(:match_result, :batting_average, :pitching_result)
      .where(user:)
      .where.not(match_result_id: nil)
      .joins(:match_result)
      .order('match_results.date_and_time DESC')
      .map do |game_result|
      {
        game_result_id: game_result.id,
        match_result: game_result.match_result,
        batting_average: game_result.batting_average,
        pitching_result: game_result.pitching_result
      }
    end
  end

  def self.filtered_game_associated_data_user(user, year, match_type)
    game_results = base_query(user)
    game_results = filter_by_year(game_results, year) if year_filter_applicable?(year)
    game_results = filter_by_match_type(game_results, match_type) if match_type_filter_applicable?(match_type)

    map_game_results(game_results)
  end

  def self.base_query(user)
    includes(:match_result, :batting_average, :pitching_result).where(user:)
                                                               .where.not(match_result_id: nil)
  end

  def self.year_filter_applicable?(year)
    year.present? && year != '通算'
  end

  def self.filter_by_year(game_results, year)
    start_date = Date.new(year.to_i, 1, 1)
    end_date = Date.new(year.to_i, 12, 31)
    game_results.where(match_results: { date_and_time: start_date..end_date })
  end

  def self.match_type_filter_applicable?(match_type)
    match_type.present? && match_type != '全て'
  end

  def self.filter_by_match_type(game_results, match_type)
    game_results.where(match_results: { match_type: })
  end

  def self.map_game_results(game_results)
    game_results.map do |game_result|
      {
        game_result_id: game_result.id,
        match_result: game_result.match_result,
        batting_average: game_result.batting_average,
        pitching_result: game_result.pitching_result
      }
    end
  end

  # === v2 API メソッド ===
  # v1との違い: .mapでハッシュに変換せず、ActiveRecord::Relationのまま返す。
  # シリアライザー(V2::GameResultSerializer等)に整形を委譲することで、
  # opponent_team_name, tournament_name, plate_appearances を1リクエストで返却可能にする。

  # 特定ユーザーの試合一覧を関連データ付きで取得する（認証ユーザー向け）
  # match_result -> opponent_team, tournament と plate_appearances, batting_average, pitching_result を eager-load し、
  # N+1クエリを防止する
  # @param user [User, Integer] Userオブジェクトまたはuser_id
  # @return [ActiveRecord::Relation<GameResult>] 日付降順の試合結果リレーション
  def self.v2_game_associated_data_user(user)
    includes(
      match_result: %i[opponent_team tournament],
      plate_appearances: [],
      batting_average: [],
      pitching_result: []
    ).where(user: user).where.not(match_result_id: nil)
     .joins(:match_result).order('match_results.date_and_time DESC')
  end

  # 特定ユーザーの試合一覧を年度・試合種別でフィルタリングして取得する
  # @param user [User, Integer] Userオブジェクトまたはuser_id
  # @param year [String, nil] フィルタ対象の年度（"通算"の場合はフィルタなし）
  # @param match_type [String, nil] フィルタ対象の試合種別（"全て"の場合はフィルタなし）
  # @return [ActiveRecord::Relation<GameResult>] フィルタ済みの試合結果リレーション
  def self.v2_filtered_game_associated_data_user(user, year, match_type)
    game_results = v2_game_associated_data_user(user)
    game_results = filter_by_year(game_results, year) if year_filter_applicable?(year)
    game_results = filter_by_match_type(game_results, match_type) if match_type_filter_applicable?(match_type)
    game_results
  end

  # 全ユーザーの試合一覧を関連データ付きで取得する（タイムライン表示向け）
  # ユーザー情報も含めてeager-loadする
  # @return [ActiveRecord::Relation<GameResult>] 日付降順の全ユーザー試合結果リレーション
  def self.v2_all_game_associated_data
    includes(
      :user,
      match_result: %i[opponent_team tournament],
      plate_appearances: [],
      pitching_result: []
    ).where.not(match_result_id: nil)
     .joins(:match_result).order('match_results.date_and_time DESC')
  end
end
