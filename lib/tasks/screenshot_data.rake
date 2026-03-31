namespace :screenshot_data do
  desc 'スクリーンショット用のデモデータを作成'
  task create: :environment do
    puts 'スクリーンショット用データを作成中...'

    # チーム作成
    category = BaseballCategory.find_by(name: '高校生') || BaseballCategory.first
    prefecture = Prefecture.find_by(name: '東京都') || Prefecture.first
    team = Team.find_or_create_by!(name: 'BUZZ学園高校') do |t|
      t.category_id = category&.id
      t.prefecture_id = prefecture&.id
    end
    puts "  チーム: #{team.name}"

    # 対戦相手チーム
    opponent_teams = %w[
      星光学院 青葉台高校 東都実業 桜丘高校
      翔英高校 北斗学園 南海高校 西武台高校
    ].map do |name|
      Team.find_or_create_by!(name:) do |t|
        t.category_id = category&.id
        t.prefecture_id = prefecture&.id
      end
    end

    # ポジション取得
    positions = {
      pitcher: Position.find_by(name: '投手'),
      catcher: Position.find_by(name: '捕手'),
      first: Position.find_by(name: '一塁手'),
      second: Position.find_by(name: '二塁手'),
      third: Position.find_by(name: '三塁手'),
      short: Position.find_by(name: '遊撃手'),
      left: Position.find_by(name: '左翼手'),
      center: Position.find_by(name: '中堅手'),
      right: Position.find_by(name: '右翼手')
    }

    # 9人のユーザー定義
    user_defs = [
      { name: 'バズ太郎', user_id: 'buzz_taro', email: 'buzz_taro@example.com',
        intro: '打てるピッチャーになりたい。ストレートの最速は131km/h。目指せ140km/h！',
        pos: %i[pitcher right], batting_order: 1, defensive_position: '投手', is_pitcher: true },
      { name: 'バズ次郎', user_id: 'buzz_jiro', email: 'buzz_jiro@example.com',
        intro: 'キャッチャーとして配球を勉強中。盗塁阻止率を上げたい。',
        pos: [:catcher], batting_order: 2, defensive_position: '捕手', is_pitcher: false },
      { name: 'バズ三郎', user_id: 'buzz_saburo', email: 'buzz_saburo@example.com',
        intro: '長打が持ち味。ホームラン量産を目指してます。',
        pos: [:first], batting_order: 4, defensive_position: '一塁手', is_pitcher: false },
      { name: 'バズ花子', user_id: 'buzz_hanako', email: 'buzz_hanako@example.com',
        intro: '守備範囲の広さが自慢。ゲッツーを決めるのが快感。',
        pos: [:second], batting_order: 7, defensive_position: '二塁手', is_pitcher: false },
      { name: 'バズ健太', user_id: 'buzz_kenta', email: 'buzz_kenta@example.com',
        intro: 'サードの守備を磨いてます。強肩を活かしたい。',
        pos: [:third], batting_order: 5, defensive_position: '三塁手', is_pitcher: false },
      { name: 'バズ翔太', user_id: 'buzz_shota', email: 'buzz_shota@example.com',
        intro: '俊足が武器。盗塁王を狙ってます。',
        pos: [:short], batting_order: 6, defensive_position: '遊撃手', is_pitcher: false },
      { name: 'バズ陽菜', user_id: 'buzz_hina', email: 'buzz_hina@example.com',
        intro: 'ミート力を上げるために毎日ティーバッティング100本。',
        pos: [:left], batting_order: 8, defensive_position: '左翼手', is_pitcher: false },
      { name: 'バズ大輔', user_id: 'buzz_daisuke', email: 'buzz_daisuke@example.com',
        intro: '広い守備範囲でチームを支えたい。足には自信あり。',
        pos: [:center], batting_order: 9, defensive_position: '中堅手', is_pitcher: false },
      { name: 'バズ美咲', user_id: 'buzz_misaki', email: 'buzz_misaki@example.com',
        intro: '勝負強い打撃が持ち味。チャンスに強い打者を目指す。',
        pos: [:right], batting_order: 3, defensive_position: '右翼手', is_pitcher: false }
    ]

    users = user_defs.map do |d|
      user = User.find_or_initialize_by(email: d[:email])
      user.assign_attributes(
        name: d[:name],
        user_id: d[:user_id],
        password: 'password123',
        password_confirmation: 'password123',
        provider: 'email',
        uid: d[:email],
        confirmed_at: Time.current,
        introduction: d[:intro],
        team_id: team.id,
        is_private: false
      )
      user.save!

      # ポジション設定
      user.positions = d[:pos].filter_map { |p| positions[p] }

      puts "  ユーザー: #{user.name} (@#{user.user_id})"
      { user:, **d }
    end

    # シーズン作成
    users.each do |u|
      Season.find_or_create_by!(user: u[:user], name: '2026年春季')
    end

    # 試合データ作成
    match_types = %w[regular regular regular open]
    base_date = Date.new(2026, 3, 1)

    users.each do |u|
      user = u[:user]
      season = Season.find_by(user:, name: '2026年春季')
      game_count = rand(5..8)

      game_count.times do |i|
        game_date = base_date + (i * rand(3..5))
        opponent = opponent_teams.sample
        my_score = rand(0..12)
        opp_score = rand(0..8)
        game_time = game_date.to_datetime + 13.hours

        ActiveRecord::Base.transaction do
          # GameResultを先に作成
          game_result = GameResult.create!(user:, created_at: game_time, updated_at: game_time)

          # MatchResult作成（game_resultを渡す）
          match_result = MatchResult.create!(
            game_result:,
            user:,
            my_team_id: team.id,
            opponent_team_id: opponent.id,
            date_and_time: game_time,
            match_type: match_types.sample,
            my_team_score: my_score,
            opponent_team_score: opp_score,
            batting_order: u[:batting_order],
            defensive_position: u[:defensive_position],
            memo: ''
          )
          game_result.update!(match_result_id: match_result.id)

          # BattingAverage作成（リアルな成績）
          at_bats = rand(2..5)
          hit = weighted_hit(at_bats)
          two_base = if hit.positive?
                       rand < 0.2 ? 1 : 0
                     else
                       0
                     end
          three_base = if hit > 1
                         rand < 0.05 ? 1 : 0
                       else
                         0
                       end
          home_run = if hit.positive?
                       rand < 0.08 ? 1 : 0
                     else
                       0
                     end
          single = [hit - two_base - three_base - home_run, 0].max
          total_bases = single + (two_base * 2) + (three_base * 3) + (home_run * 4)
          bb = rand < 0.3 ? rand(0..2) : 0
          hbp = rand < 0.05 ? 1 : 0
          sf = rand < 0.08 ? 1 : 0
          sh = rand < 0.1 ? 1 : 0
          times_at_bat = at_bats + bb + hbp + sf + sh
          rbi = hit.positive? && rand < 0.4 ? rand(1..3) : 0
          run = hit.positive? && rand < 0.3 ? 1 : 0
          so = (at_bats - hit).positive? ? rand(0..[at_bats - hit, 2].min) : 0
          sb = rand < 0.15 ? rand(1..2) : 0
          cs = sb.positive? && rand < 0.3 ? 1 : 0
          error = rand < 0.05 ? 1 : 0

          batting = BattingAverage.create!(
            user:,
            game_result:,
            plate_appearances: times_at_bat,
            times_at_bat:,
            at_bats:,
            hit:,
            two_base_hit: two_base,
            three_base_hit: three_base,
            home_run:,
            total_bases:,
            runs_batted_in: rbi,
            run:,
            strike_out: so,
            base_on_balls: bb,
            hit_by_pitch: hbp,
            sacrifice_hit: sh,
            sacrifice_fly: sf,
            stealing_base: sb,
            caught_stealing: cs,
            error:
          )
          game_result.update!(batting_average_id: batting.id)

          # 打席結果作成
          create_plate_appearances(
            game_result:, user:, at_bats:, hit:,
            two_base:, three_base:, home_run:,
            base_on_balls: bb, hit_by_pitch: hbp, strike_out: so, sacrifice_fly: sf, sacrifice_hit: sh
          )

          # 投手成績（バズ太郎のみ）
          if u[:is_pitcher]
            ip_whole = rand(5..9)
            ip_frac = [0, 1, 2].sample
            innings = (ip_whole + (ip_frac / 3.0)).round(1)
            pitching = PitchingResult.create!(
              user:,
              game_result:,
              win: my_score > opp_score ? 1 : 0,
              loss: my_score < opp_score ? 1 : 0,
              hold: 0,
              saves: 0,
              innings_pitched: innings,
              number_of_pitches: (innings * rand(13..17)).to_i,
              got_to_the_distance: ip_whole >= 9,
              run_allowed: opp_score,
              earned_run: [opp_score - rand(0..1), 0].max,
              hits_allowed: opp_score + rand(1..4),
              home_runs_hit: rand < 0.3 ? rand(0..1) : 0,
              strikeouts: rand(3..10),
              base_on_balls: rand(0..3),
              hit_by_pitch: rand < 0.2 ? 1 : 0
            )
            game_result.update!(pitching_result_id: pitching.id)
          end

          game_result.update!(season_id: season&.id)
        end
      end

      game_count_actual = user.game_results.count
      puts "    試合データ: #{game_count_actual}試合"
    end

    # グループ作成
    group = Group.find_or_create_by!(name: 'BUZZ学園')
    puts "  グループ: #{group.name}"

    # メンバー追加
    users.each do |u|
      user = u[:user]
      GroupUser.find_or_create_by!(user:, group:)
      GroupInvitation.find_or_create_by!(user:, group:) do |inv|
        inv.state = :accepted
        inv.sent_at = Time.current
        inv.responded_at = Time.current
      end
    end
    puts "    メンバー: #{group.group_users.count}人"

    # フォロー関係（全員相互フォロー）
    all_users = users.pluck(:user)
    all_users.combination(2).each do |a, b|
      Relationship.find_or_create_by!(follower_id: a.id, followed_id: b.id) { |r| r.status = :accepted }
      Relationship.find_or_create_by!(follower_id: b.id, followed_id: a.id) { |r| r.status = :accepted }
    end
    puts '    相互フォロー設定完了'

    # ランキングスナップショット更新
    begin
      Group.find_each do |g|
        GroupRankingSnapshotService.new(g, g.users).update_snapshots
      end
      puts '    ランキングスナップショット更新完了'
    rescue StandardError => e
      puts "    ランキングスナップショット更新スキップ: #{e.message}"
    end

    puts 'スクリーンショット用データの作成が完了しました！'
    puts 'メインアカウント: buzz_taro@example.com / password123'
  end
end

def weighted_hit(at_bats)
  # 打率.250-.350程度になるようなヒット数を生成
  hits = 0
  at_bats.times { hits += 1 if rand < 0.3 }
  hits
end

# 打撃結果の定義: [result_id, position_ids, short_form]
# position_ids: その結果で使いうるポジションID群
BATTING_RESULT_MAP = {
  'single' => { result_id: 7,  positions: (1..9).to_a, short: '安' },
  'double' => { result_id: 8,  positions: [7, 8, 9],   short: '二' },
  'triple' => { result_id: 9,  positions: [7, 8, 9],   short: '三' },
  'home_run' => { result_id: 10, positions: [7, 8, 9], short: '本' },
  'strikeout' => { result_id: 13, positions: [0], short: '三振' },
  'walk' => { result_id: 15, positions: [0], short: '四球' },
  'hit_by_pitch' => { result_id: 16, positions: [0], short: '死球' },
  'sacrifice_fly' => { result_id: 12, positions: [7, 8, 9], short: '犠飛' },
  'sacrifice_hit' => { result_id: 11, positions: [1, 2, 3], short: '犠打' },
  'groundout' => { result_id: 1,  positions: (1..6).to_a, short: 'ゴ' },
  'flyout' => { result_id: 2, positions: [7, 8, 9], short: '飛' },
  'lineout' => { result_id: 4, positions: (1..9).to_a, short: '直' }
}.freeze

POSITION_LABELS = { 0 => '', 1 => '投', 2 => '捕', 3 => '一', 4 => '二', 5 => '三', 6 => '遊', 7 => '左', 8 => '中', 9 => '右' }.freeze

def create_plate_appearances(**params) # rubocop:disable Metrics/MethodLength
  game_result = params[:game_result]
  user = params[:user]
  at_bats = params[:at_bats]
  hit = params[:hit]
  two_base = params[:two_base]
  three_base = params[:three_base]
  home_run = params[:home_run]

  results = []

  single = [hit - two_base - three_base - home_run, 0].max
  single.times { results << 'single' }
  two_base.times { results << 'double' }
  three_base.times { results << 'triple' }
  home_run.times { results << 'home_run' }
  params[:strike_out].times { results << 'strikeout' }
  params[:base_on_balls].times { results << 'walk' }
  params[:hit_by_pitch].times { results << 'hit_by_pitch' }
  params[:sacrifice_fly].times { results << 'sacrifice_fly' }
  params[:sacrifice_hit].times { results << 'sacrifice_hit' }

  remaining = at_bats - hit - params[:strike_out]
  remaining.times { results << %w[groundout flyout lineout].sample } if remaining.positive?

  results.shuffle.each_with_index do |result_key, i|
    mapping = BATTING_RESULT_MAP[result_key]
    position_id = mapping[:positions].sample
    result_id = mapping[:result_id]
    position_label = POSITION_LABELS[position_id] || ''
    batting_result = "#{position_label}#{mapping[:short]}"

    PlateAppearance.create!(
      game_result:,
      user:,
      batter_box_number: i + 1,
      batting_result:,
      batting_position_id: position_id,
      plate_result_id: result_id
    )
  end
end
