# Production-like Seed Data for BUZZ BASE
# 本番環境と同等のデータ構造で新規開発者がすぐに開発を開始できるシードデータ

Rails.logger.debug '🚀 Creating production-like seed data for BUZZ BASE...'
Rails.logger.debug 'This will create comprehensive, realistic data that matches production environment structure.'

# データ期間設定（過去60日間で本番環境と同等のデータ構造を作成）
end_date = Date.current
start_date = 60.days.ago.to_date

Rails.logger.debug { "\n📅 Creating test data from #{start_date} to #{end_date}..." }

# 必要なマスターデータの存在チェック
required_models = %w[Position]
missing_models = required_models.select { |model| model.constantize.count.zero? }

if missing_models.any?
  Rails.logger.debug { "❌ Warning: Required master data missing: #{missing_models.join(', ')}" }
  Rails.logger.debug '   Please run: bundle exec rails db:seed SEED_TYPE=development first'
  exit 1
end

# 基本設定
positions = Position.all
Rails.logger.debug { "✅ Found #{positions.count} positions" }

# 1. ユーザーデータの作成（過去60日間で段階的に増加）
Rails.logger.debug 'Creating users...'
user_count = 0
(start_date..end_date).each_with_index do |date, index|
  # 日によって新規ユーザー数を変動（0-5人/日）
  daily_new_users = [0, 1, 1, 2, 2, 3, 4, 5].sample

  daily_new_users.times do |i|
    user_count += 1
    user = User.create!(
      email: "testuser#{user_count}@example.com",
      password: 'password123',
      name: "テストユーザー#{user_count}",
      user_id: "testuser#{user_count}",
      created_at: date.beginning_of_day + (i * 2).hours,
      updated_at: date.beginning_of_day + (i * 2).hours,
      confirmed_at: date.beginning_of_day + (i * 2).hours
    )

    # ユーザーのポジション関連付け（ランダムなポジションを選択）
    selected_position = positions.sample
    UserPosition.create!(
      user:,
      position: selected_position
    )
  end

  Rails.logger.debug '.' if (index % 10).zero?
end
Rails.logger.debug { "\nCreated #{User.count} users" }

# 2. チームデータの作成
Rails.logger.debug 'Creating teams...'
10.times do |i|
  Team.create!(
    name: "テストチーム#{i + 1}",
    created_at: (start_date + rand(60).days).beginning_of_day
  )
end
Rails.logger.debug { "Created #{Team.count} teams" }

# 3. ゲーム結果とマッチ結果データの作成（本番環境と同等の関連付け）
Rails.logger.debug 'Creating game results with proper match associations...'
game_count = 0
teams = Team.all
match_types = %w[練習試合 公式戦 トーナメント リーグ戦 交流戦]

(start_date..end_date).each_with_index do |date, index|
  # 既存ユーザーからランダムに選択
  available_users = User.where('created_at <= ?', date.end_of_day)
  next if available_users.count < 2

  # 日によってゲーム数を変動（0-6試合/日、より現実的な分布）
  daily_games = [0, 0, 1, 1, 2, 2, 3, 4, 5, 6].sample

  daily_games.times do |_i|
    user = available_users.sample
    my_team = teams.sample
    opponent_team = teams.where.not(id: my_team.id).sample

    # より現実的な試合時間の設定
    game_hour = [10, 13, 14, 15, 18, 19].sample
    game_time = date.beginning_of_day + game_hour.hours + rand(30).minutes

    # トランザクションで整合性を保つ
    ActiveRecord::Base.transaction do
      game_count += 1

      # まずGameResultを作成
      game_result = GameResult.create!(
        user:,
        created_at: game_time,
        updated_at: game_time
      )

      # より現実的なスコア設定
      my_score = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].sample
      opponent_score = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].sample

      # 守備位置の現実的な分布（投手・捕手は少なく、内野手・外野手を多く）
      defensive_positions = [1, 2, 3, 4, 5, 6, 7, 8, 9] # 投手少なく、他均等
      defensive_position = defensive_positions.sample

      # MatchResultを作成してGameResultと正しく関連付け
      match_result = MatchResult.create!(
        game_result:,
        user:,
        date_and_time: game_time,
        match_type: match_types.sample,
        my_team:,
        opponent_team:,
        my_team_score: my_score,
        opponent_team_score: opponent_score,
        batting_order: rand(1..9),
        defensive_position:,
        memo: '本番環境と同等のテストデータ',
        created_at: game_time,
        updated_at: game_time
      )

      # GameResultのmatch_result_idを正しく設定
      game_result.update!(match_result_id: match_result.id)
    end
  end

  Rails.logger.debug '.' if (index % 10).zero?
end
Rails.logger.debug { "\nCreated #{GameResult.count} game results with proper match associations" }

# 4. 打撃成績データの作成（より現実的な数値で作成）
Rails.logger.debug 'Creating realistic batting averages...'
batting_count = 0
available_game_results = GameResult.joins(:match_result)

available_game_results.each_with_index do |game_result, index|
  # ゲーム結果に対して85%の確率で打撃成績を作成（より現実的）
  next if rand > 0.85

  batting_count += 1

  # 現実的な打数配分
  plate_appearances = rand(3..5)
  at_bats = [plate_appearances - rand(0..1), 1].max
  hits = rand(0..at_bats)

  # 長打は安打の一部
  two_base_hit = hits.positive? ? rand(0..[hits, 1].min) : 0
  three_base_hit = hits > 1 ? rand(0..[hits - two_base_hit, 1].min) : 0
  home_run = hits.positive? ? rand(0..[hits - two_base_hit - three_base_hit, 1].min) : 0

  # 打点、得点は安打数と連動
  runs_batted_in = rand(0..[hits + rand(2), 4].min)
  runs = rand(0..[hits + rand(2), 3].min)

  BattingAverage.create!(
    user: game_result.user,
    game_result:,
    plate_appearances:,
    at_bats:,
    hit: hits,
    two_base_hit:,
    three_base_hit:,
    home_run:,
    runs_batted_in:,
    run: runs,
    strike_out: rand(0..[at_bats - hits, 3].min),
    base_on_balls: plate_appearances - at_bats,
    stealing_base: rand(0..1),
    created_at: game_result.created_at + rand(30).minutes,
    updated_at: game_result.created_at + rand(30).minutes
  )

  Rails.logger.debug '.' if (index % 20).zero?
end
Rails.logger.debug { "\nCreated #{BattingAverage.count} realistic batting records" }

# 5. 投手成績データの作成（守備位置が投手の場合のみ）
Rails.logger.debug 'Creating realistic pitching results...'
pitching_count = 0
# 投手として登録されたゲーム結果のみ取得
pitcher_game_results = GameResult.joins(:match_result)
                                 .where(match_results: { defensive_position: 1 })

pitcher_game_results.each_with_index do |game_result, index|
  # 投手の場合95%の確率で投手成績を作成
  next if rand > 0.95

  pitching_count += 1

  # 現実的な投手成績の計算
  innings_pitched = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0].sample
  hits_allowed = rand(2..(innings_pitched.to_i + 6))
  runs_allowed = rand(0..[hits_allowed / 2, 8].min)
  earned_runs = rand(0..runs_allowed)

  # 勝敗はゲーム結果と連動
  my_score = game_result.match_result.my_team_score
  opponent_score = game_result.match_result.opponent_team_score
  win = my_score > opponent_score ? rand(0..1) : 0
  loss = my_score < opponent_score ? rand(0..1) : 0

  PitchingResult.create!(
    user: game_result.user,
    game_result:,
    win:,
    loss:,
    hold: win.zero? && loss.zero? ? rand(0..1) : 0,
    saves: 0, # セーブは特定条件下のみ
    innings_pitched:,
    hits_allowed:,
    run_allowed: runs_allowed,
    earned_run: earned_runs,
    base_on_balls: rand(0..5),
    strikeouts: rand((innings_pitched * 0.5).to_i..(innings_pitched * 1.5).to_i),
    home_runs_hit: rand(0..[earned_runs / 2, 2].min),
    created_at: game_result.created_at + rand(30).minutes,
    updated_at: game_result.created_at + rand(30).minutes
  )

  Rails.logger.debug '.' if (index % 10).zero?
end
Rails.logger.debug { "\nCreated #{PitchingResult.count} realistic pitching records for pitchers only" }

# 6. ユーザーアクティビティ（ログイン履歴的なデータ）の作成
# Note: 実際のモデルがない場合は、既存データの updated_at を更新してアクティビティを模擬
Rails.logger.debug 'Simulating user activities...'
(start_date..end_date).each_with_index do |date, index|
  available_users = User.where('created_at <= ?', date.end_of_day)
  next if available_users.count.zero?

  # 日によってアクティブユーザー数を変動（既存ユーザーの30-80%）
  active_user_ratio = rand(0.3..0.8)
  active_user_count = (available_users.count * active_user_ratio).to_i

  # ランダムにユーザーを選んでアクティビティを記録
  available_users.sample(active_user_count).each_with_index do |user, _i|
    # updated_at を更新してアクティビティを記録
    # rubocop:disable Rails/SkipsModelValidations
    user.touch(:updated_at, time: date.beginning_of_day + rand(18).hours + rand(60).minutes)
    # rubocop:enable Rails/SkipsModelValidations
  end

  Rails.logger.debug '.' if (index % 10).zero?
end

# 6. 野球ノートデータの作成
Rails.logger.debug 'Creating baseball notes...'
note_count = 0
note_categories = %w[打撃練習 守備練習 投球練習 試合反省 目標設定 トレーニング]
note_templates = [
  '今日の練習で気づいたことを記録します。',
  '試合での反省と次回の改善点をまとめました。',
  'コーチからのアドバイスを忘れないように記録します。',
  '明日の目標と重点的に取り組むべきことを整理しました。'
]

User.find_each do |user|
  # ユーザー当たり0-5件のノートを作成
  note_count_for_user = rand(0..5)

  note_count_for_user.times do
    note_date = rand(start_date..end_date)
    note_count += 1

    # JSON形式でmemoを作成（アプリケーションの実際の形式に合わせる）
    memo_content = [
      {
        'type' => 'paragraph',
        'children' => [
          {
            'text' => "#{note_templates.sample}\n\n具体的な内容や数値は実際の使用時に入力してください。"
          }
        ]
      }
    ]

    BaseballNote.create!(
      user:,
      title: "#{note_categories.sample} - #{note_date.strftime('%m/%d')}",
      date: note_date,
      memo: memo_content.to_json,
      created_at: note_date.beginning_of_day + rand(18).hours,
      updated_at: note_date.beginning_of_day + rand(18).hours
    )
  end
end
Rails.logger.debug { "Created #{BaseballNote.count} baseball notes" }

# 7. データ整合性チェック
Rails.logger.debug "\nPerforming data integrity checks..."
game_results_with_match = GameResult.joins(:match_result).count
game_results_without_match = GameResult.where(match_result_id: nil).count
orphaned_match_results = MatchResult.where.missing(:game_result).count

if game_results_without_match.positive?
  Rails.logger.debug { "⚠️  Warning: #{game_results_without_match} GameResults without MatchResult found" }
else
  Rails.logger.debug '✓ All GameResults have proper MatchResult associations'
end

if orphaned_match_results.positive?
  Rails.logger.debug { "⚠️  Warning: #{orphaned_match_results} orphaned MatchResults found" }
else
  Rails.logger.debug '✓ All MatchResults have proper GameResult associations'
end

Rails.logger.debug "\n\n=== Production-like Seed Data Creation Summary ==="
Rails.logger.debug { "Period: #{start_date} to #{end_date} (#{(end_date - start_date).to_i + 1} days)" }
Rails.logger.debug { "Users: #{User.count}" }
Rails.logger.debug { "User Positions: #{UserPosition.count}" }
Rails.logger.debug { "Teams: #{Team.count}" }
Rails.logger.debug { "Game Results: #{GameResult.count}" }
Rails.logger.debug { "Match Results: #{MatchResult.count}" }
Rails.logger.debug { "Batting Records: #{BattingAverage.count}" }
Rails.logger.debug { "Pitching Records: #{PitchingResult.count}" }
Rails.logger.debug { "Baseball Notes: #{BaseballNote.count}" }
Rails.logger.debug { "\n✓ GameResults with MatchResult: #{game_results_with_match}" }
Rails.logger.debug "\n🎉 Production-like seed data creation completed!"
Rails.logger.debug "\nThis data structure matches production environment and allows new developers to:"
Rails.logger.debug '  - View realistic game lists with proper associations'
Rails.logger.debug '  - Test all analytics features with meaningful data'
Rails.logger.debug '  - Experience the full application workflow'
Rails.logger.debug "\nYou can now run analytics rake tasks:"
Rails.logger.debug '  bundle exec rake analytics:daily_job'
Rails.logger.debug { "  bundle exec rake analytics:daily_job_batch[#{start_date},#{end_date}]" }
Rails.logger.debug "\nTo recreate this data, run:"
Rails.logger.debug '  bundle exec rails db:seed SEED_TYPE=production_like_seed_data'
