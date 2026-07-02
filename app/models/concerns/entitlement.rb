# 機能アクセス権（Entitlement）を判定するための concern。User に include して使う。
# 機能キーは FREE_FEATURES（常に true）と PRO_FEATURES（Pro 加入時のみ true）で構成する。
module Entitlement
  extend ActiveSupport::Concern

  # 無料プランで利用可能な機能キー。Pro 加入の有無に関わらず常に許可される。
  FREE_FEATURES = [
    'basic_game_record',     # 試合記録(基本): 試合結果・打撃成績の入力と表示
    'basic_stats',           # 基本成績集計: 打率・防御率などの基本指標
    'group_ranking',         # グループ内ランキング機能
    'calculation_tools',     # 打率・防御率などの計算ツール
    'baseball_note_basic',   # 野球ノート(基本): 練習・試合の振り返りメモ
    'shadow_swing_basic',    # 素振りカウンター(基本): スイング回数の記録
    'practice_log_basic',    # 練習記録(基本): 練習内容のログ
    'grass_recent_30days',   # 草機能: 直近30日分のヒートマップ表示
    'monthly_goal_single',   # 月次目標: 1つまで作成可
    'schedule_single'        # 自主練スケジュール: 1つまで作成可
  ].freeze

  # Pro 加入時のみ利用可能な機能キー。subscription が pro_active? のとき true。
  PRO_FEATURES = [
    'no_ads',                       # 広告非表示
    'season_transition_graph',      # シーズン跨ぎ成績推移グラフ(複数シーズン比較)
    'grass_full_history',           # 草機能: 全期間ヒートマップ表示
    'unlimited_practice_menus',     # 練習メニュー無制限(無料は3件まで)
    'unlimited_media_uploads',      # 動画・画像アップロード無制限(無料は月3件)
    'media_long_term_storage',      # メディア長期保管(31日以上前も閲覧可)
    'unlimited_schedules',          # 自主練スケジュール無制限(無料は1件まで)
    'unlimited_monthly_goals',      # 月次目標無制限(無料は1件まで)
    'season_goals',                 # シーズン目標(無料は利用不可)
    'tournament_goals',             # 大会目標(無料は利用不可)
    'custom_notification_messages', # カスタム通知メッセージの設定
    'advanced_goal_tracking',       # 高度な目標トラッキング(達成率の詳細推移)
    'detailed_condition_log',       # 詳細コンディションログ(体調・気分の詳細記録)
    'unlimited_improvement_themes', # 課題テーマ無制限(無料は取組中1つまで)
    'correlation_insights',         # 相関インサイト(練習量・コンディション×成績の傾向)
    'unlimited_reflection_templates', # 振り返りテンプレの自作無制限(無料は1つまで・プリセットは全員可)
    'advanced_periodic_review' # 週次/月次レポートの詳細(課題別内訳・相関・成績前週比・月次)
  ].freeze

  ALL_FEATURES = (FREE_FEATURES + PRO_FEATURES).freeze

  # 指定 feature_key にユーザーがアクセス可能か。
  # 無料機能は常に true、Pro 機能は subscription が pro_active? のときのみ true。
  # 命名はクライアント側 `hasEntitlement` と揃えるため Naming/PredicateName を無効化する。
  # @param feature_key [String]
  # @return [Boolean]
  # @raise [ArgumentError] 未知の feature_key が渡されたとき
  def has_entitlement?(feature_key) # rubocop:disable Naming/PredicateName
    raise ArgumentError, "Unknown feature: #{feature_key}" unless ALL_FEATURES.include?(feature_key)
    return true if FREE_FEATURES.include?(feature_key)

    pro_active?
  end
end
