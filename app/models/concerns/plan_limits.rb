# 無料プランの数量制限を表すビジネスルール。User に include して使う。
# 各 can_*? は Pro Entitlement を保有していれば即 true、無料時は現在の保有数で判定する。
# カウント取得側のメソッドは User 本体（実関連のあるメソッド）で上書きする想定だが、
# 関連未実装の機能は 0 を返すデフォルト実装で済む。
module PlanLimits
  extend ActiveSupport::Concern

  PRACTICE_MENU_FREE_LIMIT = 5
  MEDIA_UPLOAD_FREE_LIMIT_PER_MONTH = 3
  SCHEDULE_FREE_LIMIT = 3
  MONTHLY_GOAL_FREE_LIMIT = 2
  IMPROVEMENT_THEME_FREE_LIMIT = 1
  REFLECTION_TEMPLATE_FREE_LIMIT = 1

  # 練習メニューを新規作成できるか。無料は archived 以外5つまで。
  # @return [Boolean]
  def can_create_practice_menu?
    return true if has_entitlement?('unlimited_practice_menus')

    practice_menus_count_for_business_rules < PRACTICE_MENU_FREE_LIMIT
  end

  # 当月のメディアアップロードが可能か。無料は月3点まで。
  # @return [Boolean]
  def can_upload_media_this_month?
    return true if has_entitlement?('unlimited_media_uploads')

    media_attachments_count_this_month < MEDIA_UPLOAD_FREE_LIMIT_PER_MONTH
  end

  # 自主練スケジュールを新規作成できるか。無料は active なものが1つまで。
  # @return [Boolean]
  def can_create_schedule?
    return true if has_entitlement?('unlimited_schedules')

    active_schedules_count < SCHEDULE_FREE_LIMIT
  end

  # 月次目標を新規作成できるか。無料は active なものが1つまで。
  # @return [Boolean]
  def can_create_monthly_goal?
    return true if has_entitlement?('unlimited_monthly_goals')

    active_monthly_goals_count < MONTHLY_GOAL_FREE_LIMIT
  end

  # シーズン目標を新規作成できるか。Pro 限定機能。
  # @return [Boolean]
  def can_create_season_goal?
    has_entitlement?('season_goals')
  end

  # 大会目標を新規作成できるか。Pro 限定機能。
  # @return [Boolean]
  def can_create_tournament_goal?
    has_entitlement?('tournament_goals')
  end

  # 課題テーマを新規作成できるか。無料は取組中（open）が1つまで。
  # @return [Boolean]
  def can_create_improvement_theme?
    return true if has_entitlement?('unlimited_improvement_themes')

    open_improvement_themes_count < IMPROVEMENT_THEME_FREE_LIMIT
  end

  # 振り返りテンプレを自作できるか。無料は1つまで。プリセット利用は本制限の対象外。
  # @return [Boolean]
  def can_create_reflection_template?
    return true if has_entitlement?('unlimited_reflection_templates')

    custom_reflection_templates_count < REFLECTION_TEMPLATE_FREE_LIMIT
  end

  private

  # 各 Pro 機能 issue で実関連に差し替える。関連未実装のため現状は 0 を返す。
  def practice_menus_count_for_business_rules
    practice_menus.where(archived: false).count
  end

  def media_attachments_count_this_month
    0
  end

  def active_schedules_count
    schedules.active.count
  end

  def active_monthly_goals_count
    goals.active.monthly.count
  end

  def open_improvement_themes_count
    improvement_themes.where(status: 'open').count
  end

  def custom_reflection_templates_count
    reflection_templates.count
  end
end
