# 機能アクセス権（Entitlement）を判定するための concern。User に include して使う。
# 機能キーは FREE_FEATURES（常に true）と PRO_FEATURES（Pro 加入時のみ true）で構成する。
module Entitlement
  extend ActiveSupport::Concern

  FREE_FEATURES = %w[
    basic_game_record
    basic_stats
    group_ranking
    calculation_tools
    baseball_note_basic
    shadow_swing_basic
    practice_log_basic
    grass_recent_30days
    monthly_goal_single
    schedule_single
  ].freeze

  PRO_FEATURES = %w[
    no_ads
    season_transition_graph
    grass_full_history
    unlimited_practice_menus
    unlimited_media_uploads
    media_long_term_storage
    unlimited_schedules
    unlimited_monthly_goals
    season_goals
    custom_notification_messages
    advanced_goal_tracking
    detailed_condition_log
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
