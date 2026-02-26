# 開発環境データ作成タスク
# rake dev_data:setup   -- マスターデータ + サンプルデータを一括作成
# rake dev_data:master  -- マスターデータのみ
# rake dev_data:sample  -- サンプルデータのみ（マスターデータが必要）
# rake dev_data:reset   -- DB再作成 + setup

namespace :dev_data do # rubocop:disable Metrics/BlockLength
  desc '開発環境データを一括作成（マスターデータ + サンプルデータ）'
  task setup: :environment do
    Rake::Task['dev_data:master'].invoke
    Rake::Task['dev_data:sample'].invoke
  end

  desc 'マスターデータを作成（Position, Prefecture, BaseballCategory, Admin::User）'
  task master: :environment do
    Rails.logger.debug 'Creating master data...'

    # Positions
    positions = %w[投手 捕手 一塁手 二塁手 三塁手 遊撃手 左翼手 中堅手 右翼手 指名打者]
    positions.each do |name|
      Position.find_or_create_by!(name:)
    end
    Rails.logger.debug { "Positions: #{Position.count}" }

    # Prefectures
    prefectures = [
      { name: '北海道', hiragana: 'ほっかいどう', katakana: 'ホッカイドウ', alphabet: 'Hokkaido' },
      { name: '青森県', hiragana: 'あおもりけん', katakana: 'アオモリケン', alphabet: 'Aomori' },
      { name: '岩手県', hiragana: 'いわてけん', katakana: 'イワテケン', alphabet: 'Iwate' },
      { name: '宮城県', hiragana: 'みやぎけん', katakana: 'ミヤギケン', alphabet: 'Miyagi' },
      { name: '秋田県', hiragana: 'あきたけん', katakana: 'アキタケン', alphabet: 'Akita' },
      { name: '山形県', hiragana: 'やまがたけん', katakana: 'ヤマガタケン', alphabet: 'Yamagata' },
      { name: '福島県', hiragana: 'ふくしまけん', katakana: 'フクシマケン', alphabet: 'Fukushima' },
      { name: '茨城県', hiragana: 'いばらきけん', katakana: 'イバラキケン', alphabet: 'Ibaraki' },
      { name: '栃木県', hiragana: 'とちぎけん', katakana: 'トチギケン', alphabet: 'Tochigi' },
      { name: '群馬県', hiragana: 'ぐんまけん', katakana: 'グンマケン', alphabet: 'Gunma' },
      { name: '埼玉県', hiragana: 'さいたまけん', katakana: 'サイタマケン', alphabet: 'Saitama' },
      { name: '千葉県', hiragana: 'ちばけん', katakana: 'チバケン', alphabet: 'Chiba' },
      { name: '東京都', hiragana: 'とうきょうと', katakana: 'トウキョウト', alphabet: 'Tokyo' },
      { name: '神奈川県', hiragana: 'かながわけん', katakana: 'カナガワケン', alphabet: 'Kanagawa' },
      { name: '新潟県', hiragana: 'にいがたけん', katakana: 'ニイガタケン', alphabet: 'Niigata' },
      { name: '富山県', hiragana: 'とやまけん', katakana: 'トヤマケン', alphabet: 'Toyama' },
      { name: '石川県', hiragana: 'いしかわけん', katakana: 'イシカワケン', alphabet: 'Ishikawa' },
      { name: '福井県', hiragana: 'ふくいけん', katakana: 'フクイケン', alphabet: 'Fukui' },
      { name: '山梨県', hiragana: 'やまなしけん', katakana: 'ヤマナシケン', alphabet: 'Yamanashi' },
      { name: '長野県', hiragana: 'ながのけん', katakana: 'ナガノケン', alphabet: 'Nagano' },
      { name: '岐阜県', hiragana: 'ぎふけん', katakana: 'ギフケン', alphabet: 'Gifu' },
      { name: '静岡県', hiragana: 'しずおかけん', katakana: 'シズオカケン', alphabet: 'Shizuoka' },
      { name: '愛知県', hiragana: 'あいちけん', katakana: 'アイチケン', alphabet: 'Aichi' },
      { name: '三重県', hiragana: 'みえけん', katakana: 'ミエケン', alphabet: 'Mie' },
      { name: '滋賀県', hiragana: 'しがけん', katakana: 'シガケン', alphabet: 'Shiga' },
      { name: '京都府', hiragana: 'きょうとふ', katakana: 'キョウトフ', alphabet: 'Kyoto' },
      { name: '大阪府', hiragana: 'おおさかふ', katakana: 'オオサカフ', alphabet: 'Osaka' },
      { name: '兵庫県', hiragana: 'ひょうごけん', katakana: 'ヒョウゴケン', alphabet: 'Hyogo' },
      { name: '奈良県', hiragana: 'ならけん', katakana: 'ナラケン', alphabet: 'Nara' },
      { name: '和歌山県', hiragana: 'わかやまけん', katakana: 'ワカヤマケン', alphabet: 'Wakayama' },
      { name: '鳥取県', hiragana: 'とっとりけん', katakana: 'トットリケン', alphabet: 'Tottori' },
      { name: '島根県', hiragana: 'しまねけん', katakana: 'シマネケン', alphabet: 'Shimane' },
      { name: '岡山県', hiragana: 'おかやまけん', katakana: 'オカヤマケン', alphabet: 'Okayama' },
      { name: '広島県', hiragana: 'ひろしまけん', katakana: 'ヒロシマケン', alphabet: 'Hiroshima' },
      { name: '山口県', hiragana: 'やまぐちけん', katakana: 'ヤマグチケン', alphabet: 'Yamaguchi' },
      { name: '徳島県', hiragana: 'とくしまけん', katakana: 'トクシマケン', alphabet: 'Tokushima' },
      { name: '香川県', hiragana: 'かがわけん', katakana: 'カガワケン', alphabet: 'Kagawa' },
      { name: '愛媛県', hiragana: 'えひめけん', katakana: 'エヒメケン', alphabet: 'Ehime' },
      { name: '高知県', hiragana: 'こうちけん', katakana: 'コウチケン', alphabet: 'Kochi' },
      { name: '福岡県', hiragana: 'ふくおかけん', katakana: 'フクオカケン', alphabet: 'Fukuoka' },
      { name: '佐賀県', hiragana: 'さがけん', katakana: 'サガケン', alphabet: 'Saga' },
      { name: '長崎県', hiragana: 'ながさきけん', katakana: 'ナガサキケン', alphabet: 'Nagasaki' },
      { name: '熊本県', hiragana: 'くまもとけん', katakana: 'クマモトケン', alphabet: 'Kumamoto' },
      { name: '大分県', hiragana: 'おおいたけん', katakana: 'オオイタケン', alphabet: 'Oita' },
      { name: '宮崎県', hiragana: 'みやざきけん', katakana: 'ミヤザキケン', alphabet: 'Miyazaki' },
      { name: '鹿児島県', hiragana: 'かごしまけん', katakana: 'カゴシマケン', alphabet: 'Kagoshima' },
      { name: '沖縄県', hiragana: 'おきなわけん', katakana: 'オキナワケン', alphabet: 'Okinawa' },
      { name: 'その他', hiragana: 'そのた', katakana: 'ソノタ', alphabet: 'Sonota' }
    ]
    prefectures.each do |pref|
      Prefecture.find_or_create_by!(name: pref[:name]) do |p|
        p.hiragana = pref[:hiragana]
        p.katakana = pref[:katakana]
        p.alphabet = pref[:alphabet]
      end
    end
    Rails.logger.debug { "Prefectures: #{Prefecture.count}" }

    # BaseballCategories
    categories = [
      { name: '小学生（硬式）', hiragana: 'しょうがくせい（こうしき）', katakana: 'ショウガクセイ（コウシキ）', alphabet: 'Shogakusei (Koushiki)' },
      { name: '小学生（軟式）', hiragana: 'しょうがくせい（なんしき）', katakana: 'ショウガクセイ（ナンシキ）', alphabet: 'Shogakusei (Nanshiki)' },
      { name: 'ボーイズリーグ（中学生）', hiragana: 'ぼーいずりーぐ（ちゅうがくせいのぶ）', katakana: 'ボーイズリーグ（チュウガクセイ）', alphabet: 'Boys League (Chuugakusei)' },
      { name: 'リトルシニアリーグ（中学生）', hiragana: 'りとるしにありーぐ（ちゅうがくせいのぶ）', katakana: 'リトルシニアリーグ（チュウガクセイ）',
        alphabet: 'Little Senior League (Chuugakusei)' },
      { name: 'ヤングリーグ（中学生）', hiragana: 'やんぐりーぐ（ちゅうがくせいのぶ）', katakana: 'ヤングリーグ（チュウガクセイ）', alphabet: 'Young League (Chuugakusei)' },
      { name: 'ポニーリーグ（中学生）', hiragana: 'ぽにーりーぐ（ちゅうがくせいのぶ）', katakana: 'ポニーリーグ（チュウガクセイ）', alphabet: 'Pony League (Chuugakusei)' },
      { name: 'プロンコリーグ（中学生）', hiragana: 'ぷろんこりーぐ（ちゅうがくせいのぶ）', katakana: 'プロンコリーグ（チュウガクセイ）', alphabet: 'Bronco League (Chuugakusei)' },
      { name: 'フレッシュリーグ（中学生）', hiragana: 'ふれっしゅりーぐ（ちゅうがくせいのぶ）', katakana: 'フレッシュリーグ（チュウガクセイ）', alphabet: 'Fresh League (Chuugakusei)' },
      { name: 'ジャパンリーグ（中学生）', hiragana: 'じゃぱんりーぐ', katakana: 'ジャパンリーグ', alphabet: 'Japan League' },
      { name: '中学（軟式）', hiragana: 'ちゅうがく（なんしき）', katakana: 'チュウガク（ナンシキ）', alphabet: 'Chugaku (Nanshiki)' },
      { name: '高校（硬式）', hiragana: 'こうこう（こうしき）', katakana: 'コウコウ（コウシキ）', alphabet: 'Koukou (Koushiki)' },
      { name: '高校（軟式）', hiragana: 'こうこう（なんしき）', katakana: 'コウコウ（ナンシキ）', alphabet: 'Koukou (Nanshiki)' },
      { name: 'その他', hiragana: 'そのた', katakana: 'ソノタ', alphabet: 'Sonota' }
    ]
    categories.each do |cat|
      BaseballCategory.find_or_create_by!(name: cat[:name]) do |c|
        c.hiragana = cat[:hiragana]
        c.katakana = cat[:katakana]
        c.alphabet = cat[:alphabet]
      end
    end
    Rails.logger.debug { "BaseballCategories: #{BaseballCategory.count}" }

    # Admin User
    Admin::User.find_or_create_by!(email: 'admin_2@example.com') do |admin|
      admin.name = 'Admin User'
      admin.password = 'password123'
    end
    Rails.logger.debug { "Admin Users: #{Admin::User.count}" }

    Rails.logger.debug 'Master data creation completed!'
  end

  desc 'サンプルデータを作成（Users, Teams, GameResults等）— マスターデータが必要'
  task sample: :environment do
    if Position.count.zero?
      Rails.logger.debug 'Position data not found. Please run `rake dev_data:master` first.'
      exit 1
    end

    Rails.logger.debug 'Creating sample data...'
    positions = Position.all

    # --- Users（20人） ---
    Rails.logger.debug 'Creating users...'
    users = []
    20.times do |i|
      n = i + 1
      user = User.find_or_create_by!(email: "dev#{n}@example.com") do |u|
        u.password = 'password123'
        u.name = "開発ユーザー#{n}"
        u.user_id = "devuser#{n}"
        u.confirmed_at = Time.current
      end
      users << user

      UserPosition.find_or_create_by!(user:, position: positions.sample)
    end
    Rails.logger.debug { "Users: #{User.count}" }

    # --- Teams（5チーム） ---
    Rails.logger.debug 'Creating teams...'
    team_names = %w[ブルースターズ レッドファルコンズ グリーンイーグルス ホワイトベアーズ ブラックパンサーズ]
    teams = team_names.map do |name|
      Team.find_or_create_by!(name:)
    end
    Rails.logger.debug { "Teams: #{Team.count}" }

    # --- GameResult + MatchResult + BattingAverage + PitchingResult ---
    Rails.logger.debug 'Creating game results...'
    match_types = %w[練習試合 公式戦 トーナメント リーグ戦 交流戦]

    users.each do |user|
      game_count = rand(3..5)
      game_count.times do |_gi|
        my_team = teams.sample
        opponent_team = teams.reject { |t| t.id == my_team.id }.sample
        game_time = rand(1..60).days.ago + rand(8..18).hours

        defensive_positions = [1, 2, 3, 4, 5, 6, 7, 8, 9]
        defensive_position = defensive_positions.sample

        my_score = rand(0..12)
        opponent_score = rand(0..12)

        ActiveRecord::Base.transaction do
          game_result = GameResult.create!(
            user:,
            created_at: game_time,
            updated_at: game_time
          )

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
            memo: '開発用テストデータ',
            created_at: game_time,
            updated_at: game_time
          )

          game_result.update!(match_result_id: match_result.id)

          # BattingAverage（85%の確率）
          if rand < 0.85
            plate_appearances = rand(3..5)
            base_on_balls = rand < 0.08 ? 1 : 0
            hit_by_pitch = rand < 0.03 ? 1 : 0
            sacrifice_hit = rand < 0.05 ? 1 : 0
            sacrifice_fly = rand < 0.04 ? 1 : 0
            at_bats = [plate_appearances - base_on_balls - hit_by_pitch - sacrifice_hit - sacrifice_fly, 1].max

            # 各打席ごとに約27%の確率でヒット（現実的な打率 .250〜.300）
            hits = (0...at_bats).count { rand < 0.27 }

            # 長打の内訳（安打のうち約20%が二塁打、3%が三塁打、5%が本塁打）
            remaining = hits
            home_run = remaining.positive? && rand < 0.05 ? 1 : 0
            remaining -= home_run
            three_base_hit = remaining.positive? && rand < 0.03 ? 1 : 0
            remaining -= three_base_hit
            two_base_hit = remaining.positive? && rand < 0.20 ? 1 : 0

            total_bases = hits + two_base_hit + (three_base_hit * 2) + (home_run * 3)

            batting_average = BattingAverage.create!(
              user:,
              game_result:,
              plate_appearances:,
              at_bats:,
              times_at_bat: at_bats,
              hit: hits,
              two_base_hit:,
              three_base_hit:,
              home_run:,
              total_bases:,
              runs_batted_in: hits.positive? ? rand(0..[hits, 3].min) : 0,
              run: hits.positive? ? rand(0..[hits, 2].min) : 0,
              strike_out: rand(0..[at_bats - hits, 2].min),
              base_on_balls:,
              hit_by_pitch:,
              sacrifice_hit:,
              sacrifice_fly:,
              stealing_base: rand < 0.10 ? 1 : 0,
              caught_stealing: rand < 0.03 ? 1 : 0,
              error: rand < 0.05 ? 1 : 0,
              created_at: game_time,
              updated_at: game_time
            )

            game_result.update!(batting_average_id: batting_average.id)
          end

          # PitchingResult（投手の場合のみ）
          next unless defensive_position == 1

          innings_pitched = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0].sample
          hits_allowed = rand(2..(innings_pitched.to_i + 6))
          runs_allowed = rand(0..[hits_allowed / 2, 8].min)
          earned_runs = rand(0..runs_allowed)
          win = my_score > opponent_score ? rand(0..1) : 0
          loss = my_score < opponent_score ? rand(0..1) : 0
          got_to_the_distance = innings_pitched >= 9.0

          pitching_result = PitchingResult.create!(
            user:,
            game_result:,
            win:,
            loss:,
            hold: win.zero? && loss.zero? ? rand(0..1) : 0,
            saves: 0,
            innings_pitched:,
            number_of_pitches: (innings_pitched * rand(12..18)).to_i,
            got_to_the_distance:,
            hits_allowed:,
            run_allowed: runs_allowed,
            earned_run: earned_runs,
            base_on_balls: rand(0..5),
            strikeouts: rand((innings_pitched * 0.5).to_i..(innings_pitched * 1.5).to_i),
            home_runs_hit: rand(0..[earned_runs / 2, 2].min),
            hit_by_pitch: rand(0..2),
            created_at: game_time,
            updated_at: game_time
          )

          game_result.update!(pitching_result_id: pitching_result.id)
        end
      end
    end
    Rails.logger.debug { "GameResults: #{GameResult.count}" }
    Rails.logger.debug { "BattingAverages: #{BattingAverage.count}" }
    Rails.logger.debug { "PitchingResults: #{PitchingResult.count}" }

    # --- Groups（2グループ） ---
    Rails.logger.debug 'Creating groups...'
    2.times do |i|
      group_name = "開発テストグループ#{i + 1}"
      group = Group.find_or_create_by!(name: group_name)

      members = users.sample(10)
      members.each do |user|
        GroupUser.find_or_create_by!(user:, group:)
        GroupInvitation.find_or_create_by!(user:, group:) do |inv|
          inv.state = :accepted
          inv.sent_at = Time.current
        end
      end
    end
    Rails.logger.debug { "Groups: #{Group.count}" }

    # --- BaseballNotes ---
    Rails.logger.debug 'Creating baseball notes...'
    note_categories = %w[打撃練習 守備練習 投球練習 試合反省 目標設定 トレーニング]
    note_templates = [
      '今日の練習で気づいたことを記録します。',
      '試合での反省と次回の改善点をまとめました。',
      'コーチからのアドバイスを忘れないように記録します。',
      '明日の目標と重点的に取り組むべきことを整理しました。'
    ]

    users.first(10).each do |user|
      rand(1..3).times do
        note_date = rand(1..30).days.ago.to_date
        memo_content = [
          {
            'type' => 'paragraph',
            'children' => [{ 'text' => note_templates.sample }]
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
    Rails.logger.debug { "BaseballNotes: #{BaseballNote.count}" }

    # --- Relationships（フォロー関係） ---
    Rails.logger.debug 'Creating relationships...'
    users.first(10).each do |follower|
      followed_users = users.reject { |u| u.id == follower.id }.sample(rand(2..5))
      followed_users.each do |followed|
        Relationship.find_or_create_by!(follower_id: follower.id, followed_id: followed.id)
      end
    end
    Rails.logger.debug { "Relationships: #{Relationship.count}" }

    Rails.logger.debug "\n=== Sample Data Creation Summary ==="
    Rails.logger.debug { "Users: #{User.count}" }
    Rails.logger.debug { "Teams: #{Team.count}" }
    Rails.logger.debug { "GameResults: #{GameResult.count}" }
    Rails.logger.debug { "BattingAverages: #{BattingAverage.count}" }
    Rails.logger.debug { "PitchingResults: #{PitchingResult.count}" }
    Rails.logger.debug { "Groups: #{Group.count}" }
    Rails.logger.debug { "BaseballNotes: #{BaseballNote.count}" }
    Rails.logger.debug { "Relationships: #{Relationship.count}" }
    Rails.logger.debug 'Sample data creation completed!'
  end

  desc 'DB再作成 + 開発環境データ一括作成'
  task reset: :environment do
    # 他のセッションを切断してからdrop
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      SELECT pg_terminate_backend(pg_stat_activity.pid)
      FROM pg_stat_activity
      WHERE pg_stat_activity.datname = current_database()
        AND pid <> pg_backend_pid()
    SQL
    ActiveRecord::Base.connection_pool.disconnect!

    Rake::Task['db:drop'].invoke
    Rake::Task['db:create'].invoke
    Rake::Task['db:migrate'].invoke
    Rake::Task['dev_data:setup'].invoke
  end
end
