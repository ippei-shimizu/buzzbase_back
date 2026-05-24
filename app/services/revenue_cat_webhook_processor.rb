# RevenueCat Webhook payload を Subscription 更新に変換するエントリポイント。
# 未対応イベントも Sentry warning を残しつつ processed として記録し、RevenueCat 側の再送ループを防ぐ。
class RevenueCatWebhookProcessor
  STORE_TO_PLATFORM = {
    'APP_STORE' => 'ios',
    'MAC_APP_STORE' => 'ios',
    'PLAY_STORE' => 'android',
    'STRIPE' => 'web'
  }.freeze

  PRODUCT_ID_TO_PLAN_TYPE = {
    'buzzbase_pro_monthly' => 'monthly',
    'buzzbase_pro_yearly' => 'yearly'
  }.freeze

  def initialize(webhook_event)
    @webhook_event = webhook_event
    @payload = webhook_event.payload || {}
    @event_data = @payload['event'] || {}
  end

  # failed のレコードは手動で再 enqueue されたとき再処理する設計のため processed のみガードする。
  def process
    return if @webhook_event.processed?

    handle_event
    @webhook_event.mark_processed!
  rescue StandardError => e
    @webhook_event.mark_failed!(e.message)
    Sentry.capture_exception(e, tags: { source: 'revenuecat_webhook' })
    raise
  end

  private

  # 既知イベントは個別 handler に振り分け、未知イベントは Sentry warning に流す。
  def handle_event
    case @event_data['type']
    when 'INITIAL_PURCHASE', 'TRIAL_STARTED'
      handle_initial_purchase
    when 'RENEWAL', 'CANCELLATION', 'EXPIRATION',
         'BILLING_ISSUE', 'PRODUCT_CHANGE', 'REFUND',
         'UNCANCELLATION'
      # TODO: 各 event_type ごとに Subscription を更新する handler を実装する
      #   - RENEWAL: expires_at を更新（古いイベントなら無視して順序非依存性を担保）
      #   - CANCELLATION: cancelled_at をセット、expires_at は維持
      #   - EXPIRATION: status を expired に
      #   - BILLING_ISSUE: billing_issue_at をセット、Grace 期間を維持
      #   - PRODUCT_CHANGE: plan_type を切替
      #   - REFUND: status を expired に、expires_at を即時切れに、refunded_at をセット
      #   - UNCANCELLATION: cancelled_at をクリアし active に戻す
      nil
    else
      Sentry.capture_message(
        "RevenueCat unknown event_type: #{@event_data['type'].inspect}",
        level: :warning
      )
    end
  end

  # INITIAL_PURCHASE / TRIAL_STARTED 兼用。period_type で trial / active を出し分け、
  # 早期特典窓内のタイムスタンプなら is_early_subscriber を立てる。
  def handle_initial_purchase
    user = find_user
    return notify_unknown_user unless user

    is_trial = @event_data['period_type'] == 'TRIAL'
    started_at = epoch_ms_to_time(@event_data['event_timestamp_ms'])
    subscription = user.subscription_or_default

    subscription.update!(
      status: is_trial ? 'trial' : 'active',
      plan_type: detect_plan_type(@event_data['product_id']),
      platform: detect_platform(@event_data['store']),
      product_id: @event_data['product_id'],
      started_at:,
      expires_at: epoch_ms_to_time(@event_data['expiration_at_ms']),
      has_used_trial: is_trial || subscription.has_used_trial,
      is_early_subscriber: TrialDaysCalculator.in_early_window?(started_at),
      revenuecat_user_id: @event_data['app_user_id'],
      last_synced_at: Time.current
    )

    record_subscription_event(user, is_trial ? 'trial_started' : 'initial_purchase')
  end

  # app_user_id は mobile/front から `user.id.to_s` を渡す前提。
  # 初回 INITIAL_PURCHASE 前は subscription.revenuecat_user_id が nil のため User.id で fallback する。
  def find_user
    app_user_id = @event_data['app_user_id']
    return nil if app_user_id.blank?

    Subscription.find_by(revenuecat_user_id: app_user_id)&.user ||
      User.find_by(id: app_user_id)
  end

  def notify_unknown_user
    Sentry.capture_message(
      "RevenueCat: user not found for app_user_id=#{@event_data['app_user_id'].inspect}",
      level: :warning
    )
    nil
  end

  def detect_plan_type(product_id)
    PRODUCT_ID_TO_PLAN_TYPE[product_id]
  end

  def detect_platform(store)
    STORE_TO_PLATFORM[store]
  end

  def epoch_ms_to_time(ms)
    return nil if ms.nil?

    Time.zone.at(ms.to_i / 1000)
  end

  # 監査ログに同一 revenuecat_event_id が既に書かれていれば握り潰す（冪等性確保）。
  def record_subscription_event(user, event_type)
    UserSubscriptionEvent.create!(
      user:,
      subscription: user.subscription,
      event_type:,
      platform: detect_platform(@event_data['store']),
      product_id: @event_data['product_id'],
      period_type: @event_data['period_type'],
      occurred_at: epoch_ms_to_time(@event_data['event_timestamp_ms']) || Time.current,
      raw_payload: @event_data,
      revenuecat_event_id: @event_data['id']
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
