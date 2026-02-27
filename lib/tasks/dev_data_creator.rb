# 開発環境データ作成ヘルパー
# dev_data.rake から呼び出される
class DevDataCreator # rubocop:disable Metrics/ClassLength
  PREFECTURES = [
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
  ].freeze

  BASEBALL_CATEGORIES = [
    { name: '小学生（硬式）', hiragana: 'しょうがくせい（こうしき）', katakana: 'ショウガクセイ（コウシキ）', alphabet: 'Shogakusei (Koushiki)' },
    { name: '小学生（軟式）', hiragana: 'しょうがくせい（なんしき）', katakana: 'ショウガクセイ（ナンシキ）', alphabet: 'Shogakusei (Nanshiki)' },
    { name: 'ボーイズリーグ（中学生）', hiragana: 'ぼーいずりーぐ（ちゅうがくせいのぶ）', katakana: 'ボーイズリーグ（チュウガクセイ）',
      alphabet: 'Boys League (Chuugakusei)' },
    { name: 'リトルシニアリーグ（中学生）', hiragana: 'りとるしにありーぐ（ちゅうがくせいのぶ）', katakana: 'リトルシニアリーグ（チュウガクセイ）',
      alphabet: 'Little Senior League (Chuugakusei)' },
    { name: 'ヤングリーグ（中学生）', hiragana: 'やんぐりーぐ（ちゅうがくせいのぶ）', katakana: 'ヤングリーグ（チュウガクセイ）',
      alphabet: 'Young League (Chuugakusei)' },
    { name: 'ポニーリーグ（中学生）', hiragana: 'ぽにーりーぐ（ちゅうがくせいのぶ）', katakana: 'ポニーリーグ（チュウガクセイ）',
      alphabet: 'Pony League (Chuugakusei)' },
    { name: 'プロンコリーグ（中学生）', hiragana: 'ぷろんこりーぐ（ちゅうがくせいのぶ）', katakana: 'プロンコリーグ（チュウガクセイ）',
      alphabet: 'Bronco League (Chuugakusei)' },
    { name: 'フレッシュリーグ（中学生）', hiragana: 'ふれっしゅりーぐ（ちゅうがくせいのぶ）', katakana: 'フレッシュリーグ（チュウガクセイ）',
      alphabet: 'Fresh League (Chuugakusei)' },
    { name: 'ジャパンリーグ（中学生）', hiragana: 'じゃぱんりーぐ', katakana: 'ジャパンリーグ', alphabet: 'Japan League' },
    { name: '中学（軟式）', hiragana: 'ちゅうがく（なんしき）', katakana: 'チュウガク（ナンシキ）', alphabet: 'Chugaku (Nanshiki)' },
    { name: '高校（硬式）', hiragana: 'こうこう（こうしき）', katakana: 'コウコウ（コウシキ）', alphabet: 'Koukou (Koushiki)' },
    { name: '高校（軟式）', hiragana: 'こうこう（なんしき）', katakana: 'コウコウ（ナンシキ）', alphabet: 'Koukou (Nanshiki)' },
    { name: 'その他', hiragana: 'そのた', katakana: 'ソノタ', alphabet: 'Sonota' }
  ].freeze

  class << self
    def create_positions
      %w[投手 捕手 一塁手 二塁手 三塁手 遊撃手 左翼手 中堅手 右翼手 指名打者].each do |name|
        Position.find_or_create_by!(name:)
      end
      Rails.logger.debug { "Positions: #{Position.count}" }
    end

    def create_prefectures
      PREFECTURES.each do |pref|
        Prefecture.find_or_create_by!(name: pref[:name]) do |p|
          p.hiragana = pref[:hiragana]
          p.katakana = pref[:katakana]
          p.alphabet = pref[:alphabet]
        end
      end
      Rails.logger.debug { "Prefectures: #{Prefecture.count}" }
    end

    def create_baseball_categories
      BASEBALL_CATEGORIES.each do |cat|
        BaseballCategory.find_or_create_by!(name: cat[:name]) do |c|
          c.hiragana = cat[:hiragana]
          c.katakana = cat[:katakana]
          c.alphabet = cat[:alphabet]
        end
      end
      Rails.logger.debug { "BaseballCategories: #{BaseballCategory.count}" }
    end

    def create_admin_user
      Admin::User.find_or_create_by!(email: 'admin_2@example.com') do |admin|
        admin.name = 'Admin User'
        admin.password = 'password123'
      end
      Rails.logger.debug { "Admin Users: #{Admin::User.count}" }
    end

    def create_users
      positions = Position.all
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
      users
    end

    def create_teams
      team_names = %w[ブルースターズ レッドファルコンズ グリーンイーグルス ホワイトベアーズ ブラックパンサーズ]
      teams = team_names.map { |name| Team.find_or_create_by!(name:) }
      Rails.logger.debug { "Teams: #{Team.count}" }
      teams
    end

    def create_game_results(users, teams)
      match_types = %w[練習試合 公式戦 トーナメント リーグ戦 交流戦]
      users.each do |user|
        rand(3..5).times do
          my_team = teams.sample
          opponent_team = teams.reject { |t| t.id == my_team.id }.sample
          game_time = rand(1..60).days.ago + rand(8..18).hours

          ActiveRecord::Base.transaction do
            game_result = create_single_game(user, my_team, opponent_team, game_time, match_types)
            create_batting_average(user, game_result, game_time)
            create_pitching_result_if_pitcher(user, game_result, game_time)
          end
        end
      end
      Rails.logger.debug { "GameResults: #{GameResult.count}" }
      Rails.logger.debug { "BattingAverages: #{BattingAverage.count}" }
      Rails.logger.debug { "PitchingResults: #{PitchingResult.count}" }
    end

    def create_relationships(users)
      Rails.logger.debug 'Creating relationships...'
      users.first(10).each do |follower|
        followed_users = users.reject { |u| u.id == follower.id }.sample(rand(2..5))
        followed_users.each do |followed|
          Relationship.find_or_create_by!(follower_id: follower.id, followed_id: followed.id) do |r|
            r.status = :accepted
          end
        end
      end
      Rails.logger.debug { "Relationships: #{Relationship.count}" }
    end

    def setup_private_accounts(users)
      Rails.logger.debug 'Setting private accounts...'
      private_users = users[17..18]
      private_users.each { |u| u.update!(is_private: true) }
      Rails.logger.debug { "Private users: #{User.where(is_private: true).count}" }
      private_users
    end

    def create_pending_follow_requests(users, private_users)
      Rails.logger.debug 'Creating pending follow requests...'
      private_users.each do |private_user|
        requesters = users.reject { |u| u.id == private_user.id }.sample(3)
        requesters.each do |requester|
          rel = Relationship.find_or_create_by!(follower_id: requester.id, followed_id: private_user.id) do |r|
            r.status = :pending
          end
          notification = Notification.create!(actor: requester, event_type: 'follow_request', event_id: rel.id)
          UserNotification.create!(user_id: private_user.id, notification_id: notification.id)
        end
      end
      Rails.logger.debug { "Pending follow requests: #{Relationship.pending.count}" }
    end

    def create_follow_notifications
      Rails.logger.debug 'Creating follow notifications...'
      Relationship.accepted.limit(5).each do |rel|
        notification = Notification.create!(actor_id: rel.follower_id, event_type: 'followed', event_id: rel.follower_id)
        UserNotification.create!(user_id: rel.followed_id, notification_id: notification.id)
      end
      Rails.logger.debug { "Notifications: #{Notification.count}" }
    end

    def create_groups(users)
      Rails.logger.debug 'Creating groups...'
      2.times do |i|
        group = Group.find_or_create_by!(name: "開発テストグループ#{i + 1}")
        owner = users[i]
        members = ensure_enough_following(owner, users)
        register_group_members([owner] + members, group)
      end
      Rails.logger.debug { "Groups: #{Group.count}" }
    end

    def create_baseball_notes(users)
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
          memo_content = [{ 'type' => 'paragraph', 'children' => [{ 'text' => note_templates.sample }] }]
          BaseballNote.create!(
            user:, title: "#{note_categories.sample} - #{note_date.strftime('%m/%d')}",
            date: note_date, memo: memo_content.to_json,
            created_at: note_date.beginning_of_day + rand(18).hours,
            updated_at: note_date.beginning_of_day + rand(18).hours
          )
        end
      end
      Rails.logger.debug { "BaseballNotes: #{BaseballNote.count}" }
    end

    def print_summary
      Rails.logger.debug "\n=== Sample Data Creation Summary ==="
      %w[User Team GameResult BattingAverage PitchingResult Relationship Notification Group BaseballNote].each do |model|
        Rails.logger.debug { "#{model}: #{model.constantize.count}" }
      end
      Rails.logger.debug { "Private Users: #{User.where(is_private: true).count}" }
      Rails.logger.debug { "Pending Relationships: #{Relationship.pending.count}" }
    end

    private

    def create_single_game(user, my_team, opponent_team, game_time, match_types)
      game_result = GameResult.create!(user:, created_at: game_time, updated_at: game_time)
      match_result = MatchResult.create!(
        game_result:, user:, date_and_time: game_time, match_type: match_types.sample,
        my_team:, opponent_team:, my_team_score: rand(0..12), opponent_team_score: rand(0..12),
        batting_order: rand(1..9), defensive_position: rand(1..9),
        memo: '開発用テストデータ', created_at: game_time, updated_at: game_time
      )
      game_result.update!(match_result_id: match_result.id)
      game_result
    end

    def create_batting_average(user, game_result, game_time)
      return unless rand < 0.85

      stats = generate_plate_stats
      extra_hits = generate_extra_base_hits(stats[:hits])

      batting_average = BattingAverage.create!(
        user:, game_result:, **batting_average_attrs(stats, extra_hits, game_time)
      )
      game_result.update!(batting_average_id: batting_average.id)
    end

    def create_pitching_result_if_pitcher(user, game_result, game_time)
      return unless game_result.match_result.defensive_position == 1

      ip = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0].sample
      ha = rand(2..(ip.to_i + 6))
      ra = rand(0..[ha / 2, 8].min)
      er = rand(0..ra)
      my_score = game_result.match_result.my_team_score
      opp_score = game_result.match_result.opponent_team_score
      win = my_score > opp_score ? rand(0..1) : 0
      loss = my_score < opp_score ? rand(0..1) : 0

      pitching_result = PitchingResult.create!(
        user:, game_result:, win:, loss:, hold: win.zero? && loss.zero? ? rand(0..1) : 0,
        saves: 0, innings_pitched: ip, number_of_pitches: (ip * rand(12..18)).to_i,
        got_to_the_distance: ip >= 9.0, hits_allowed: ha, run_allowed: ra, earned_run: er,
        base_on_balls: rand(0..5), strikeouts: rand((ip * 0.5).to_i..(ip * 1.5).to_i),
        home_runs_hit: rand(0..[er / 2, 2].min), hit_by_pitch: rand(0..2),
        created_at: game_time, updated_at: game_time
      )
      game_result.update!(pitching_result_id: pitching_result.id)
    end

    def ensure_enough_following(owner, users)
      candidates = owner.following.to_a
      if candidates.size < 9
        additional = users.reject { |u| u.id == owner.id || candidates.include?(u) }.sample(9 - candidates.size)
        additional.each do |u|
          Relationship.find_or_create_by!(follower_id: owner.id, followed_id: u.id) do |r|
            r.status = :accepted
          end
        end
        candidates = owner.following.reload.to_a
      end
      candidates.sample([9, candidates.size].min)
    end

    def register_group_members(members, group)
      members.each do |user|
        GroupUser.find_or_create_by!(user:, group:)
        GroupInvitation.find_or_create_by!(user:, group:) do |inv|
          inv.state = :accepted
          inv.sent_at = Time.current
        end
      end
    end

    def random_flag(probability)
      rand < probability ? 1 : 0
    end

    def generate_plate_stats
      pa = rand(3..5)
      bb = random_flag(0.08)
      hbp = random_flag(0.03)
      sh = random_flag(0.05)
      sf = random_flag(0.04)
      ab = [pa - bb - hbp - sh - sf, 1].max
      hits = (0...ab).count { rand < 0.27 }
      { pa:, ab:, hits:, bb:, hbp:, sh:, sf: }
    end

    def generate_extra_base_hits(hits)
      remaining = hits
      hr = remaining.positive? ? random_flag(0.05) : 0
      remaining -= hr
      tbh = remaining.positive? ? random_flag(0.03) : 0
      remaining -= tbh
      dbh = remaining.positive? ? random_flag(0.20) : 0
      { hr:, tbh:, dbh: }
    end

    def batting_average_attrs(stats, extra, game_time)
      ab = stats[:ab]
      hits = stats[:hits]
      {
        plate_appearances: stats[:pa], at_bats: ab, times_at_bat: ab,
        hit: hits, two_base_hit: extra[:dbh], three_base_hit: extra[:tbh], home_run: extra[:hr],
        total_bases: hits + extra[:dbh] + (extra[:tbh] * 2) + (extra[:hr] * 3),
        runs_batted_in: hits.positive? ? rand(0..[hits, 3].min) : 0,
        run: hits.positive? ? rand(0..[hits, 2].min) : 0,
        strike_out: rand(0..[ab - hits, 2].min),
        base_on_balls: stats[:bb], hit_by_pitch: stats[:hbp],
        sacrifice_hit: stats[:sh], sacrifice_fly: stats[:sf],
        stealing_base: random_flag(0.10), caught_stealing: random_flag(0.03), error: random_flag(0.05),
        created_at: game_time, updated_at: game_time
      }
    end
  end
end
