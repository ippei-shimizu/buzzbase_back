# 開発環境データ作成ヘルパー
# dev_data.rake から呼び出される
#
# release/game-stats-202605 で追加予定の機能（pitchers / arm_angles /
# velocity_zones / pitcher_styles / appearance_situations / stadiums /
# plate_appearances v2 詳細データ）は意図的に含めず、現在運用中の
# 既存機能のデータを実ユーザーに近い形で大量に再現する。
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

  TEAM_NAMES = %w[
    ブルースターズ レッドファルコンズ グリーンイーグルス
    ホワイトベアーズ ブラックパンサーズ
    東京ストリーム 横浜ウェーブス 大阪サンライズ
    名古屋アローズ 札幌ノーザンライツ
    福岡ハリケーンズ 広島フェニックス 京都グランディアズ
    神戸シーホークス 仙台サンダーボルツ
  ].freeze

  AWARD_TITLES = [
    '首位打者', '本塁打王', '打点王', '盗塁王',
    'ベストナイン', '新人賞', '最優秀防御率',
    '最多勝', 'セーブ王', '最優秀選手 (MVP)',
    'ゴールデングラブ', '最多奪三振', '殊勲賞'
  ].freeze

  TOURNAMENT_NAMES = %w[
    春季大会 夏季大会 秋季大会 冬季リーグ
    地区予選 県大会 都市対抗 社会人野球選手権
    高校選手権 ボーイズリーグ全国大会
    リトルシニア地区大会 中学軟式選手権
    オープン戦シリーズ 練習試合シリーズ
  ].freeze

  SEASON_NAMES = %w[2024シーズン 2025シーズン 2026シーズン].freeze

  NOTE_CATEGORIES = %w[打撃練習 守備練習 投球練習 試合反省 目標設定 トレーニング ミーティング 自主練].freeze

  NOTE_TEMPLATES = [
    '今日の練習で気づいたことを記録します。コーチからのフィードバックを踏まえて次回への改善点を整理しました。',
    '試合での反省と次回の改善点をまとめました。特にチャンスの場面での集中力が課題だと感じました。',
    'コーチからのアドバイスを忘れないように記録します。バッティングフォームの修正ポイントを意識します。',
    '明日の目標と重点的に取り組むべきことを整理しました。守備練習にも時間を割きたいです。',
    '練習メニューと取り組み内容を残します。スイングスピードの改善が次の課題です。',
    '対戦相手の傾向と次回の対策を考えました。投手の球種と配球パターンをイメージしておきます。',
    '今日の反省を踏まえて、明日からの取り組みを変えていきたいと思います。',
    '体調管理とコンディション維持の重要性を再認識しました。'
  ].freeze

  USER_NAMES = %w[
    田中太郎 佐藤花子 鈴木一郎 高橋健太 渡辺真理
    伊藤蓮 山本翔太 中村優斗 小林大輔 加藤さくら
    吉田陸 山田悠斗 佐々木遼 山口奈々 松本拓海
    井上颯太 木村光輝 林大樹 清水裕真 山崎涼介
    森智也 阿部琉生 池田結菜 橋本悠 石川駿
    山下春樹 中島陽向 前田蒼真 藤田結翔 後藤泰我
    岡田一馬 長谷川夏輝 村上湊斗 近藤朔耶 石井朝陽
    斎藤悠仁 坂本煌 遠藤湊 青木琉之介 福田隼大
    三浦悠太 西村一斗 太田悠真 藤井湊太 岡本柊
    松田岳 中川樹 中野航 原田陸斗 小川聖
  ].freeze

  # 打撃レベル: 各ユーザーに 1 段階割り当て、打席ごとの安打確率を制御する。
  BATTING_LEVELS = {
    strong: { hit: 0.34, extra: 0.32, hr: 0.06, bb: 0.10, k: 0.16 },
    regular: { hit: 0.27, extra: 0.22, hr: 0.03, bb: 0.08, k: 0.22 },
    slumped: { hit: 0.18, extra: 0.14, hr: 0.01, bb: 0.05, k: 0.30 }
  }.freeze

  # MatchResult APPEARANCE_TYPES と inning_format 候補は model のバリデーションに合わせる。
  APPEARANCE_TYPE_WEIGHTS = {
    'starter' => 80,
    'substitute' => 6,
    'pinch_hitter' => 6,
    'pinch_runner' => 4,
    'no_play' => 4
  }.freeze

  INNING_FORMATS = [9, 7].freeze

  DEVICE_TOKEN_PLATFORMS = %w[ios android].freeze

  USER_INTRODUCTIONS = [
    '中学から野球を始めて、今は外野手として頑張っています。',
    '投手として日々練習中。変化球の精度を上げたいです。',
    'チームメイトと記録を共有したくて使い始めました。',
    '打撃フォーム改善中。長打を増やしたいです。',
    'データで自分の成績を振り返るのが好きです。',
    '守備が得意。捕球の安定感を意識しています。',
    '夏の大会に向けて練習中。応援よろしくお願いします。',
    '打率 3 割を目指して頑張ります！',
    '子どもの頃から野球が大好き。社会人野球で続けています。',
    'ピッチング動画を見て勉強しています。アドバイスください！',
    '父子で野球をやってます。記録を残すために登録しました。',
    'カーブとスライダーが得意です。'
  ].freeze

  SUSPENDED_REASONS = %w[規約違反のため スパム投稿のため 迷惑行為の疑いがあったため].freeze

  # エッジケース: 集計値・UI 表示のエッジケースを必ずカバーするため、各ユーザーに 1 試合ずつ生成する。
  BATTING_EDGE_CASES = %i[perfect_game cycle_hit no_hit strike_out_show
                          walks_only homer_show rbi_show sacrifice_only].freeze
  PITCHING_EDGE_CASES = %i[complete_shutout blowout_loss many_strikeouts wild_pitch
                           save_close hold_clean long_relief_clean relief_loss].freeze
  GAME_SCORE_EDGE_CASES = %i[blowout_win blowout_loss close_win sayonara high_score].freeze

  MATCH_SCORE_EDGE_ATTRS = {
    blowout_win: { my_team_score: 15, opponent_team_score: 0 },
    blowout_loss: { my_team_score: 0, opponent_team_score: 15 },
    close_win: { my_team_score: 3, opponent_team_score: 2 },
    sayonara: { my_team_score: 5, opponent_team_score: 4 },
    high_score: { my_team_score: 18, opponent_team_score: 15 }
  }.freeze

  # mobile/constants/battingData.ts の battingResultsList と同等の id↔name マッピング。
  # 旧仕様の plate_appearances を生成するため、id を直接整数で扱う。
  PLATE_RESULT_LABELS = {
    1 => 'ゴロ', 2 => 'フライ', 3 => 'ファールフライ', 4 => 'ライナー',
    5 => 'エラー', 6 => 'フィルダースチョイス', 7 => 'ヒット',
    8 => '二塁打', 9 => '三塁打', 10 => '本塁打',
    11 => '犠打', 12 => '犠飛', 13 => '三振', 14 => '振り逃げ',
    15 => '四球', 16 => '死球', 17 => '打撃妨害',
    18 => '走塁妨害', 19 => '併殺打'
  }.freeze

  # mobile/constants/battingData.ts の battingResultsPositions と同等。
  # 旧 batting_position_id 列には 1-9 のみが入るが、batting_result の連結文字列は
  # mobile クライアントが 1-13 のラベルを使って組み立てる（実際の hit_direction_id ベース）。
  POSITION_LABELS = {
    1 => '投', 2 => '捕', 3 => '一', 4 => '二', 5 => '三', 6 => '遊',
    7 => '左線', 8 => '左', 9 => '左中', 10 => '中', 11 => '右中', 12 => '右', 13 => '右線'
  }.freeze

  # mobile/constants/battingData.ts の resultShortForms と同等。
  # 該当しない結果名はそのまま（"三振" → "三振"）。
  RESULT_SHORT_FORMS = {
    'ヒット' => '安', '二塁打' => '二', '三塁打' => '三', '本塁打' => '本',
    'ゴロ' => 'ゴ', 'フライ' => '飛',
    '打撃妨害' => '打妨', '走塁妨害' => '走妨', '併殺打' => '併'
  }.freeze

  # mobile/constants/battingData.ts の hitDirectionToLegacy と同等。
  # 1-13 の hit_direction_id を 1-9 の batting_position_id に縮約する。
  HIT_DIRECTION_TO_LEGACY = {
    1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 5, 6 => 6,
    7 => 7, 8 => 7, 9 => 7, 10 => 8, 11 => 9, 12 => 9, 13 => 9
  }.freeze

  # mobile/constants/battingData.ts の HIT_DIRECTION_DISABLED_RESULT_IDS と同等。
  # 三振・振り逃げ・四球・死球・打撃妨害・走塁妨害は打球方向の概念がない。
  NO_DIRECTION_RESULT_IDS = [13, 14, 15, 16, 17, 18].freeze

  # 本番 plate_appearances テーブルの plate_result_id 分布（2026-06-13 時点の実測値）。
  # docs/strategy/product/game-record-update-release-risk-analysis.md のクエリ A 由来。
  PLATE_RESULT_WEIGHTS = {
    1 => 2769, 7 => 2757, 2 => 1930, 15 => 1837, 13 => 1835,
    8 => 836, 5 => 549, 16 => 315, 11 => 287, 9 => 287,
    4 => 286, 10 => 285, 3 => 128, 12 => 115, 14 => 92,
    6 => 62, 19 => 51, 18 => 7, 17 => 4
  }.freeze

  # 本番 hit_direction_id 分布（NULL を除く）。クエリ C 由来。
  HIT_DIRECTION_WEIGHTS = {
    10 => 754, 8 => 735, 6 => 693, 5 => 671, 4 => 595, 12 => 535,
    3 => 446, 1 => 443, 9 => 245, 7 => 245, 2 => 121, 11 => 115, 13 => 57
  }.freeze

  # plate_result_id ごとの「hit_direction_id が埋まる確率」。本番のクエリ A 由来。
  # 方向不要結果（NO_DIRECTION_RESULT_IDS）は常に nil なのでキーを持たない。
  DIRECTION_FILL_RATE = {
    1 => 0.54, 2 => 0.57, 3 => 0.52, 4 => 0.54, 5 => 0.58, 6 => 0.42,
    7 => 0.55, 8 => 0.55, 9 => 0.46, 10 => 0.56,
    11 => 0.59, 12 => 0.35, 19 => 0.31
  }.freeze

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

    def create_awards
      AWARD_TITLES.each { |title| Award.find_or_create_by!(title:) }
      Rails.logger.debug { "Awards: #{Award.count}" }
    end

    def create_tournaments
      TOURNAMENT_NAMES.each { |name| Tournament.find_or_create_by!(name:) }
      Rails.logger.debug { "Tournaments: #{Tournament.count}" }
    end

    def create_users
      positions = Position.all
      level_keys = BATTING_LEVELS.keys
      users = []
      USER_NAMES.each_with_index do |display_name, index|
        n = index + 1
        user = User.find_or_create_by!(email: "dev#{n}@example.com") do |u|
          u.password = 'password123'
          u.name = display_name
          u.user_id = "devuser#{n}"
          u.confirmed_at = Time.current
          assign_profile_attributes(u, n)
        end
        users << user
        UserPosition.find_or_create_by!(user:, position: positions.sample)
        # 後の打撃成績生成で使う打撃レベルを user 単位でメモする。
        user.instance_variable_set(:@dev_data_batting_level, level_keys.sample)
      end
      Rails.logger.debug { "Users: #{User.count}" }
      users
    end

    # 退会・凍結ユーザーを混ぜる。本番には soft_delete / suspended 状態のレコードが
    # 存在するため、管理画面・取得 API の絞り込み（active scope）を開発環境でも検証できる。
    def apply_user_lifecycle_states(users)
      # 既存の private / 退会候補と重ならないよう、先頭から固定でピック。
      suspended_targets = users.last(5).first(3)
      deleted_targets = users.last(2)

      suspended_targets.each do |user|
        user.update!(suspended_at: rand(1..60).days.ago, suspended_reason: SUSPENDED_REASONS.sample)
      end
      deleted_targets.each do |user|
        user.update!(deleted_at: rand(1..90).days.ago)
      end
      Rails.logger.debug { "Suspended Users: #{User.suspended.count}" }
      Rails.logger.debug { "Soft Deleted Users: #{User.soft_deleted.count}" }
    end

    private

    # プロフィール属性（自己紹介・画像・ログイン日時など）を実ユーザー像に近づける。
    def assign_profile_attributes(user_builder, sequence)
      user_builder.introduction = USER_INTRODUCTIONS.sample if rand < 0.8
      # 実画像アップロードは重いので URL 文字列だけ流し込む。
      # pravatar はシード付きで毎回同じ顔を返してくれる安定アバター。
      user_builder.image = "https://i.pravatar.cc/300?u=devuser#{sequence}"
      user_builder.last_login_at = sample_last_login_at
      user_builder.last_management_notice_read_at = rand(1..60).days.ago if rand < 0.6
    end

    # 80% は直近 1 週間のアクティブユーザー / 20% は半年以上前の非アクティブを模す。
    def sample_last_login_at
      rand < 0.8 ? rand(0..7).days.ago : rand(180..365).days.ago
    end

    public

    def create_teams
      teams = TEAM_NAMES.map { |name| Team.find_or_create_by!(name:) }
      Rails.logger.debug { "Teams: #{Team.count}" }
      teams
    end

    def create_seasons(users)
      users.each do |user|
        SEASON_NAMES.each do |name|
          Season.find_or_create_by!(user:, name:)
        end
      end
      Rails.logger.debug { "Seasons: #{Season.count}" }
    end

    def create_user_awards(users)
      awards = Award.all.to_a
      users.each do |user|
        rand(0..3).times do
          award = awards.sample
          UserAward.find_or_create_by!(user:, award:)
        end
      end
      Rails.logger.debug { "UserAwards: #{UserAward.count}" }
    end

    def create_device_tokens(users)
      users.sample(users.size / 3).each do |user|
        platform = DEVICE_TOKEN_PLATFORMS.sample
        # トークン文字列は実機の Expo Push トークンに似せたランダム文字列。
        token = "ExpoPushToken[#{SecureRandom.alphanumeric(40)}]"
        DeviceToken.find_or_create_by!(user:, token:) { |t| t.platform = platform }
      end
      Rails.logger.debug { "DeviceTokens: #{DeviceToken.count}" }
    end

    def create_game_results(users, teams)
      tournaments = Tournament.all.to_a
      users.each do |user|
        seasons_by_year = user.seasons.index_by { |s| s.name[/\d{4}/].to_i }
        create_edge_case_games(user:, teams:, tournaments:, seasons_by_year:)
        # エッジケースを差し引いた残り（最低 30 試合）をランダム生成する。
        rand(30..80).times do
          my_team = teams.sample
          opponent_team = teams.reject { |t| t.id == my_team.id }.sample
          game_time = rand(1..180).days.ago + rand(8..18).hours

          context = { user:, my_team:, opponent_team:, game_time:, tournaments:, seasons_by_year: }
          ActiveRecord::Base.transaction do
            game_result = create_single_game(context)
            create_batting_average(user, game_result, game_time)
            create_pitching_result_if_pitcher(user, game_result, game_time)
            create_plate_appearances(user, game_result, game_time)
          end
        end
      end
      Rails.logger.debug { "GameResults: #{GameResult.count}" }
      Rails.logger.debug { "MatchResults: #{MatchResult.count}" }
      Rails.logger.debug { "BattingAverages: #{BattingAverage.count}" }
      Rails.logger.debug { "PitchingResults: #{PitchingResult.count}" }
      Rails.logger.debug { "PlateAppearances: #{PlateAppearance.count}" }
    end

    # 各ユーザーに対して、打撃・投手・スコアそれぞれの極端ケースを 1 試合ずつ生成する。
    # UI / 集計の境界値テストを開発環境で行いやすくする目的。
    def create_edge_case_games(user:, teams:, tournaments:, seasons_by_year:)
      context = { user:, teams:, tournaments:, seasons_by_year: }
      is_pitcher = user.positions.exists?(name: '投手')

      GAME_SCORE_EDGE_CASES.each { |edge| create_edge_case_game(context, score_edge: edge) }
      BATTING_EDGE_CASES.each { |edge| create_edge_case_game(context, batting_edge: edge) }
      return unless is_pitcher

      PITCHING_EDGE_CASES.each { |edge| create_edge_case_game(context, pitching_edge: edge) }
    end

    def create_edge_case_game(context, score_edge: nil, batting_edge: nil, pitching_edge: nil)
      user = context.fetch(:user)
      teams = context.fetch(:teams)
      my_team = teams.sample
      opponent_team = teams.reject { |t| t.id == my_team.id }.sample
      game_time = rand(1..180).days.ago + rand(8..18).hours
      score = score_edge ? MATCH_SCORE_EDGE_ATTRS.fetch(score_edge) : random_match_score
      ActiveRecord::Base.transaction do
        game_record_context = context.merge(game_time:, my_team:, opponent_team:,
                                            score:, force_starter_pitcher: pitching_edge.present?)
        game_result = build_edge_case_game_record(game_record_context)
        apply_batting_average(user, game_result, game_time, batting_edge)
        apply_pitching_result(user, game_result, game_time, pitching_edge)
        create_plate_appearances(user, game_result, game_time)
      end
    end

    def build_edge_case_game_record(context)
      user = context.fetch(:user)
      game_time = context.fetch(:game_time)
      score = context.fetch(:score)
      seasons_by_year = context.fetch(:seasons_by_year)
      tournaments = context.fetch(:tournaments)
      game_result = GameResult.create!(user:, season: seasons_by_year[game_time.year],
                                       created_at: game_time, updated_at: game_time)
      defensive_position = context.fetch(:force_starter_pitcher) ? '1' : rand(1..9).to_s
      tournament = tournaments.sample if rand < 0.3
      match_result = MatchResult.create!(
        game_result:, user:, date_and_time: game_time, match_type: %w[regular open].sample,
        my_team: context.fetch(:my_team), opponent_team: context.fetch(:opponent_team),
        my_team_score: score[:my_team_score], opponent_team_score: score[:opponent_team_score],
        batting_order: rand(1..9).to_s, defensive_position:,
        appearance_type: 'starter', inning_format: INNING_FORMATS.sample,
        tournament:, memo: '開発用テストデータ（エッジケース）',
        created_at: game_time, updated_at: game_time
      )
      game_result.update!(match_result_id: match_result.id)
      game_result
    end

    def apply_batting_average(user, game_result, game_time, batting_edge)
      attrs = batting_edge ? edge_case_batting_average_attrs(batting_edge, game_time) : nil
      return create_batting_average(user, game_result, game_time) if attrs.nil?

      batting_average = BattingAverage.create!(user:, game_result:, **attrs)
      game_result.update!(batting_average_id: batting_average.id)
    end

    def apply_pitching_result(user, game_result, game_time, pitching_edge)
      if pitching_edge
        attrs = edge_case_pitching_attrs(pitching_edge, game_time, match_result: game_result.match_result)
        pitching_result = PitchingResult.create!(user:, game_result:, **attrs)
        game_result.update!(pitching_result_id: pitching_result.id)
      else
        create_pitching_result_if_pitcher(user, game_result, game_time)
      end
    end

    def random_match_score
      { my_team_score: rand(0..12), opponent_team_score: rand(0..12) }
    end

    def create_relationships(users)
      Rails.logger.debug 'Creating relationships...'
      users.each do |follower|
        followed_users = users.reject { |u| u.id == follower.id }.sample(rand(5..20))
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
      private_users = users.sample(7)
      private_users.each { |u| u.update!(is_private: true) }
      Rails.logger.debug { "Private users: #{User.where(is_private: true).count}" }
      private_users
    end

    def create_pending_follow_requests(users, private_users)
      Rails.logger.debug 'Creating pending follow requests...'
      private_users.each do |private_user|
        requesters = users.reject { |u| u.id == private_user.id }.sample(rand(3..6))
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
      Relationship.accepted.limit(30).each do |rel|
        notification = Notification.create!(actor_id: rel.follower_id, event_type: 'followed', event_id: rel.follower_id)
        UserNotification.create!(user_id: rel.followed_id, notification_id: notification.id)
      end
      Rails.logger.debug { "Notifications: #{Notification.count}" }
    end

    def create_groups(users)
      Rails.logger.debug 'Creating groups...'
      group_names = %w[東日本チーム交流会 高校野球記録共有グループ 中学野球データ共有
                       社会人野球分析チーム 少年野球コーチ陣 大学野球研究会]
      group_names.first(rand(4..6)).each_with_index do |name, i|
        group = Group.find_or_create_by!(name:)
        owner = users[i % users.size]
        members = ensure_enough_following(owner, users, target: rand(5..15))
        register_group_members([owner] + members, group)
      end
      Rails.logger.debug { "Groups: #{Group.count}" }
      Rails.logger.debug { "GroupUsers: #{GroupUser.count}" }
    end

    def create_baseball_notes(users)
      Rails.logger.debug 'Creating baseball notes...'
      users.each do |user|
        rand(5..15).times do
          note_date = rand(1..180).days.ago.to_date
          memo_content = [{ 'type' => 'paragraph', 'children' => [{ 'text' => NOTE_TEMPLATES.sample }] }]
          BaseballNote.create!(
            user:, title: "#{NOTE_CATEGORIES.sample} - #{note_date.strftime('%m/%d')}",
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
      %w[User Team GameResult MatchResult BattingAverage PitchingResult PlateAppearance
         Season Tournament Award UserAward DeviceToken
         Relationship Notification Group GroupUser BaseballNote].each do |model|
        Rails.logger.debug { "#{model}: #{model.constantize.count}" }
      end
      Rails.logger.debug { "Private Users: #{User.where(is_private: true).count}" }
      Rails.logger.debug { "Pending Relationships: #{Relationship.pending.count}" }
    end

    private

    def create_single_game(context)
      user = context.fetch(:user)
      my_team = context.fetch(:my_team)
      opponent_team = context.fetch(:opponent_team)
      game_time = context.fetch(:game_time)
      tournaments = context.fetch(:tournaments)
      seasons_by_year = context.fetch(:seasons_by_year)
      game_result = GameResult.create!(user:, season: seasons_by_year[game_time.year],
                                       created_at: game_time, updated_at: game_time)
      appearance_type = sample_weighted(APPEARANCE_TYPE_WEIGHTS)
      # `defensive_position` は DB レベルで null: false。starter 以外は守備不在を表す "0" を入れる。
      defensive_position = appearance_type == 'starter' ? rand(1..9).to_s : '0'
      tournament = tournaments.sample if rand < 0.3
      match_result = MatchResult.create!(
        game_result:, user:, date_and_time: game_time, match_type: %w[regular open].sample,
        my_team:, opponent_team:, my_team_score: rand(0..12), opponent_team_score: rand(0..12),
        batting_order: rand(1..9).to_s, defensive_position:,
        appearance_type:, inning_format: INNING_FORMATS.sample,
        tournament:, memo: '開発用テストデータ',
        created_at: game_time, updated_at: game_time
      )
      game_result.update!(match_result_id: match_result.id)
      game_result
    end

    def create_batting_average(user, game_result, game_time)
      return if game_result.match_result.appearance_type == 'no_play'
      return unless rand < 0.9

      level = user.instance_variable_get(:@dev_data_batting_level) || :regular
      probs = BATTING_LEVELS[level]
      stats = generate_plate_stats(probs)
      extra_hits = generate_extra_base_hits(stats[:hits], probs)

      batting_average = BattingAverage.create!(
        user:, game_result:, **batting_average_attrs(stats, extra_hits, game_time)
      )
      game_result.update!(batting_average_id: batting_average.id)
    end

    def create_pitching_result_if_pitcher(user, game_result, game_time)
      match_result = game_result.match_result
      starter_pitcher = match_result.defensive_position == '1'
      relief_pitcher = !starter_pitcher && rand < 0.05
      return unless starter_pitcher || relief_pitcher

      ip = starter_pitcher ? [3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0].sample : [1.0, 2.0, 3.0].sample
      pitching_result = PitchingResult.create!(
        user:, game_result:, **pitching_result_attrs(ip:, match_result:, game_time:, starter: starter_pitcher)
      )
      game_result.update!(pitching_result_id: pitching_result.id)
    end

    # 旧仕様準拠で 1 試合分の plate_appearances を生成する。
    # 本番 DB から取得した plate_result_id / hit_direction_id 出現頻度を重み付けして
    # mobile の getResultText と同等のラベル連結で batting_result を組み立てる。
    # 新仕様カラム（rbi / run_scored / hit_location_x 等）は触らず、is_new_format も
    # default の false のままにすることで、本番旧 PA と等価な状態を再現する。
    def create_plate_appearances(user, game_result, game_time)
      return if game_result.match_result.appearance_type == 'no_play'

      batter_box_count = rand(3..5)
      batter_box_count.times do |index|
        plate_result_id = pick_weighted(PLATE_RESULT_WEIGHTS)
        hit_direction_id = sample_hit_direction(plate_result_id)
        batting_position_id = derive_batting_position_id(plate_result_id, hit_direction_id)
        batting_result = build_batting_result(plate_result_id, hit_direction_id, batting_position_id)
        timestamp = game_time + index.minutes

        PlateAppearance.create!(
          game_result:, user:,
          batter_box_number: index + 1,
          batting_result:,
          plate_result_id:,
          batting_position_id:,
          hit_direction_id:,
          is_new_format: false,
          created_at: timestamp,
          updated_at: timestamp
        )
      end
    end

    # 重み付きランダム選択（Hash{key => weight} → key）。
    def pick_weighted(weights)
      total = weights.values.sum
      threshold = rand(total)
      cumulative = 0
      weights.each do |key, weight|
        cumulative += weight
        return key if threshold < cumulative
      end
      weights.keys.last
    end

    # plate_result_id に応じて hit_direction_id を決める。
    # 方向不要結果は常に nil。それ以外は本番の埋まり率（DIRECTION_FILL_RATE）に従い、
    # 埋める場合は本番の方向別出現頻度（HIT_DIRECTION_WEIGHTS）でランダム選択。
    def sample_hit_direction(plate_result_id)
      return nil if NO_DIRECTION_RESULT_IDS.include?(plate_result_id)

      fill_rate = DIRECTION_FILL_RATE[plate_result_id] || 0.0
      return nil if rand >= fill_rate

      pick_weighted(HIT_DIRECTION_WEIGHTS)
    end

    # batting_position_id（1-9 の旧守備位置）を導出する。
    # 方向ありなら HIT_DIRECTION_TO_LEGACY で 1-9 にマップ、方向なしは
    # 本番分布に近い「0（未選択）が大多数、一部 NULL」をシミュレートする。
    def derive_batting_position_id(plate_result_id, hit_direction_id)
      return HIT_DIRECTION_TO_LEGACY[hit_direction_id] if hit_direction_id

      return nil if NO_DIRECTION_RESULT_IDS.include?(plate_result_id) && rand < 0.12

      0
    end

    # mobile/constants/battingData.ts の getResultText(positionId, resultId) と同等。
    # mobile クライアントは hit_direction_id (1-13) のラベルを使って連結するため、
    # ここも hit_direction_id 優先で POSITION_LABELS を引く。hit_direction_id が無く
    # batting_position_id だけある場合は batting_position_id の値で引く（fallback）。
    def build_batting_result(plate_result_id, hit_direction_id, batting_position_id)
      position_label = position_label_for(hit_direction_id, batting_position_id)
      result_name = PLATE_RESULT_LABELS[plate_result_id] || ''
      short_form = RESULT_SHORT_FORMS[result_name] || result_name
      "#{position_label}#{short_form}"
    end

    def position_label_for(hit_direction_id, batting_position_id)
      return POSITION_LABELS[hit_direction_id] || '' if hit_direction_id
      return '' if batting_position_id.nil? || batting_position_id.zero?

      POSITION_LABELS[batting_position_id] || ''
    end

    def ensure_enough_following(owner, users, target:)
      candidates = owner.following.to_a
      if candidates.size < target
        additional = users.reject { |u| u.id == owner.id || candidates.include?(u) }.sample(target - candidates.size)
        additional.each do |u|
          Relationship.find_or_create_by!(follower_id: owner.id, followed_id: u.id) do |r|
            r.status = :accepted
          end
        end
        candidates = owner.following.reload.to_a
      end
      candidates.sample([target, candidates.size].min)
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

    # 重み付きランダムサンプリング。{ key => weight } のハッシュから 1 つの key を返す。
    def sample_weighted(weights)
      total = weights.values.sum
      threshold = rand * total
      cumulative = 0.0
      weights.each do |key, weight|
        cumulative += weight
        return key if threshold < cumulative
      end
      weights.keys.last
    end

    def random_flag(probability)
      rand < probability ? 1 : 0
    end

    def generate_plate_stats(probs)
      pa = rand(3..5)
      bb = random_flag(probs[:bb])
      hbp = random_flag(0.03)
      sh = random_flag(0.05)
      sf = random_flag(0.04)
      ab = [pa - bb - hbp - sh - sf, 1].max
      hits = (0...ab).count { rand < probs[:hit] }
      strike_outs = (0...(ab - hits)).count { rand < probs[:k] }
      { pa:, ab:, hits:, bb:, hbp:, sh:, sf:, strike_outs: }
    end

    def generate_extra_base_hits(hits, probs)
      remaining = hits
      hr = remaining.positive? ? random_flag(probs[:hr]) : 0
      remaining -= hr
      tbh = remaining.positive? ? random_flag(0.04) : 0
      remaining -= tbh
      dbh = remaining.positive? ? random_flag(probs[:extra]) : 0
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
        strike_out: stats[:strike_outs],
        base_on_balls: stats[:bb], hit_by_pitch: stats[:hbp],
        sacrifice_hit: stats[:sh], sacrifice_fly: stats[:sf],
        stealing_base: random_flag(0.10), caught_stealing: random_flag(0.03), error: random_flag(0.05),
        created_at: game_time, updated_at: game_time
      }
    end

    def pitching_result_attrs(ip:, match_result:, game_time:, starter:)
      ha = rand(2..(ip.to_i + 6))
      ra = rand(0..[ha / 2, 8].min)
      er = rand(0..ra)
      win_flag, loss_flag, save_flag = decide_pitching_result_flags(match_result:, starter:)
      {
        win: win_flag, loss: loss_flag, hold: win_flag.zero? && loss_flag.zero? && save_flag.zero? ? rand(0..1) : 0,
        saves: save_flag,
        innings_pitched: ip,
        number_of_pitches: (ip * rand(12..18)).to_i,
        got_to_the_distance: starter && ip >= match_result.inning_format,
        hits_allowed: ha, run_allowed: ra, earned_run: er,
        base_on_balls: rand(0..5), strikeouts: rand((ip * 0.5).to_i..(ip * 1.5).to_i),
        home_runs_hit: rand(0..[er / 2, 2].min), hit_by_pitch: rand(0..2),
        created_at: game_time, updated_at: game_time
      }
    end

    # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    def edge_case_batting_average_attrs(edge, game_time)
      base = { created_at: game_time, updated_at: game_time,
               stealing_base: 0, caught_stealing: 0, error: 0,
               hit_by_pitch: 0, base_on_balls: 0, sacrifice_hit: 0, sacrifice_fly: 0,
               strike_out: 0 }
      case edge
      when :perfect_game
        base.merge(plate_appearances: 5, at_bats: 5, times_at_bat: 5,
                   hit: 5, two_base_hit: 1, three_base_hit: 0, home_run: 1,
                   total_bases: 5 + 1 + 3, runs_batted_in: 4, run: 3, stealing_base: 1)
      when :cycle_hit
        base.merge(plate_appearances: 4, at_bats: 4, times_at_bat: 4,
                   hit: 4, two_base_hit: 1, three_base_hit: 1, home_run: 1,
                   total_bases: 1 + 2 + 3 + 4, runs_batted_in: 5, run: 3)
      when :no_hit
        base.merge(plate_appearances: 4, at_bats: 4, times_at_bat: 4,
                   hit: 0, two_base_hit: 0, three_base_hit: 0, home_run: 0,
                   total_bases: 0, runs_batted_in: 0, run: 0, strike_out: 1)
      when :strike_out_show
        base.merge(plate_appearances: 4, at_bats: 4, times_at_bat: 4,
                   hit: 0, two_base_hit: 0, three_base_hit: 0, home_run: 0,
                   total_bases: 0, runs_batted_in: 0, run: 0, strike_out: 4)
      when :walks_only
        base.merge(plate_appearances: 4, at_bats: 0, times_at_bat: 0,
                   hit: 0, two_base_hit: 0, three_base_hit: 0, home_run: 0,
                   total_bases: 0, runs_batted_in: 1, run: 2, base_on_balls: 4)
      when :homer_show
        base.merge(plate_appearances: 4, at_bats: 4, times_at_bat: 4,
                   hit: 3, two_base_hit: 0, three_base_hit: 0, home_run: 2,
                   total_bases: 3 + 6, runs_batted_in: 6, run: 3)
      when :rbi_show
        base.merge(plate_appearances: 5, at_bats: 5, times_at_bat: 5,
                   hit: 4, two_base_hit: 1, three_base_hit: 0, home_run: 1,
                   total_bases: 4 + 1 + 3, runs_batted_in: 8, run: 2)
      when :sacrifice_only
        base.merge(plate_appearances: 3, at_bats: 0, times_at_bat: 0,
                   hit: 0, two_base_hit: 0, three_base_hit: 0, home_run: 0,
                   total_bases: 0, runs_batted_in: 1, run: 0,
                   sacrifice_hit: 2, sacrifice_fly: 1)
      end
    end

    def edge_case_pitching_attrs(edge, game_time, match_result:)
      base = { created_at: game_time, updated_at: game_time,
               win: 0, loss: 0, hold: 0, saves: 0,
               got_to_the_distance: false, home_runs_hit: 0, hit_by_pitch: 0 }
      case edge
      when :complete_shutout
        base.merge(win: 1, innings_pitched: match_result.inning_format.to_f,
                   number_of_pitches: 110, got_to_the_distance: true,
                   hits_allowed: 3, run_allowed: 0, earned_run: 0,
                   base_on_balls: 1, strikeouts: 9)
      when :blowout_loss
        base.merge(loss: 1, innings_pitched: 4.0, number_of_pitches: 95,
                   hits_allowed: 12, run_allowed: 10, earned_run: 9,
                   base_on_balls: 3, strikeouts: 2, home_runs_hit: 2, hit_by_pitch: 1)
      when :many_strikeouts
        base.merge(win: 1, innings_pitched: 8.0, number_of_pitches: 130,
                   hits_allowed: 5, run_allowed: 1, earned_run: 1,
                   base_on_balls: 1, strikeouts: 15)
      when :wild_pitch
        base.merge(innings_pitched: 5.0, number_of_pitches: 105,
                   hits_allowed: 6, run_allowed: 4, earned_run: 3,
                   base_on_balls: 7, strikeouts: 3, hit_by_pitch: 2)
      when :save_close
        base.merge(saves: 1, innings_pitched: 1.0, number_of_pitches: 18,
                   hits_allowed: 1, run_allowed: 0, earned_run: 0,
                   base_on_balls: 0, strikeouts: 2)
      when :hold_clean
        base.merge(hold: 1, innings_pitched: 1.0, number_of_pitches: 14,
                   hits_allowed: 0, run_allowed: 0, earned_run: 0,
                   base_on_balls: 0, strikeouts: 2)
      when :long_relief_clean
        base.merge(win: 1, innings_pitched: 4.0, number_of_pitches: 55,
                   hits_allowed: 2, run_allowed: 0, earned_run: 0,
                   base_on_balls: 1, strikeouts: 5)
      when :relief_loss
        base.merge(loss: 1, innings_pitched: 1.0, number_of_pitches: 25,
                   hits_allowed: 3, run_allowed: 3, earned_run: 3,
                   base_on_balls: 1, strikeouts: 0)
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity

    def decide_pitching_result_flags(match_result:, starter:)
      my_score = match_result.my_team_score
      opp_score = match_result.opponent_team_score
      score_diff = my_score - opp_score
      if starter
        win = score_diff.positive? ? rand(0..1) : 0
        loss = score_diff.negative? ? rand(0..1) : 0
        [win, loss, 0]
      else
        # リリーフ登板: スコア差が小さいときに save の可能性。
        save = score_diff.positive? && score_diff <= 3 ? rand(0..1) : 0
        [0, 0, save]
      end
    end
  end
end
