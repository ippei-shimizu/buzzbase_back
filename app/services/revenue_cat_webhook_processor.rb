# RevenueCat Webhook payload を Subscription 更新に変換するエントリポイント。
# 未対応イベントも Sentry warning を残しつつ processed として記録し、RevenueCat 側の再送ループを防ぐ。
# rubocop:disable Metrics/ClassLength
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
  # rubocop:disable Metrics/CyclomaticComplexity
  def handle_event
    case @event_data['type']
    when 'INITIAL_PURCHASE', 'TRIAL_STARTED' then handle_initial_purchase
    when 'RENEWAL'        then handle_renewal
    when 'CANCELLATION'   then handle_cancellation
    when 'EXPIRATION'     then handle_expiration
    when 'BILLING_ISSUE'  then handle_billing_issue
    when 'REFUND'         then handle_refund
    when 'UNCANCELLATION' then handle_uncancellation
    when 'PRODUCT_CHANGE' then handle_product_change
    else
      Sentry.capture_message(
        "RevenueCat unknown event_type: #{@event_data['type'].inspect}",
        level: :warning
      )
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  # INITIAL_PURCHASE / TRIAL_STARTED 兼用。period_type で trial / active を出し分け、
  # 早期特典期間内のタイムスタンプなら is_early_subscriber を立てる。
  def handle_initial_purchase
    with_resolved_subscription(require_persisted: false) do |user, subscription|
      is_trial = @event_data['period_type'] == 'TRIAL'
      started_at = epoch_ms_to_time(@event_data['event_timestamp_ms'])

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
  end

  # RENEWAL は順序逆転に強い実装が必要。古い expires_at のイベントが後から届いても巻き戻さない。
  # billing_issue → active への遷移時は recovered イベントも同時に記録する。
  def handle_renewal
    with_resolved_subscription do |user, subscription|
      new_expires_at = epoch_ms_to_time(@event_data['expiration_at_ms'])
      next if subscription.expires_at.present? && new_expires_at.present? && subscription.expires_at >= new_expires_at

      was_billing_issue = subscription.billing_issue?
      subscription.update!(status: 'active', expires_at: new_expires_at, last_synced_at: Time.current)
      record_subscription_event(user, 'renewed')
      # 派生イベント recovered は monitoring 用に別レコードで残す。元イベントとは別 ID にして uniqueness 衝突を回避する。
      record_subscription_event(user, 'recovered', event_id: "#{@event_data['id']}-recovered") if was_billing_issue
    end
  end

  # CANCELLATION は解約申請。期限まで Pro 機能利用可なので expires_at は変えない。
  def handle_cancellation
    with_resolved_subscription do |user, subscription|
      subscription.update!(status: 'cancelled', cancelled_at: Time.current, last_synced_at: Time.current)
      record_subscription_event(user, 'cancelled')
    end
  end

  # EXPIRATION は期限到来時の最終ステータス。Pro 機能を無効化する。
  def handle_expiration
    with_resolved_subscription do |user, subscription|
      subscription.update!(status: 'expired', last_synced_at: Time.current)
      record_subscription_event(user, 'expired')
    end
  end

  # BILLING_ISSUE は課金失敗。Grace Period 中は Pro 機能利用可なので expires_at は変えない。
  def handle_billing_issue
    with_resolved_subscription do |user, subscription|
      subscription.update!(status: 'billing_issue', billing_issue_at: Time.current, last_synced_at: Time.current)
      record_subscription_event(user, 'billing_issue')
    end
  end

  # REFUND は返金確定。Pro 機能を即時無効化するため expires_at を現在に詰める。
  def handle_refund
    with_resolved_subscription do |user, subscription|
      now = Time.current
      subscription.update!(status: 'expired', refunded_at: now, expires_at: now, last_synced_at: now)
      record_subscription_event(user, 'refunded')
    end
  end

  # UNCANCELLATION は「自動更新 ON に戻す」操作。cancelled でないときは何もしない（冪等性）。
  def handle_uncancellation
    with_resolved_subscription do |user, subscription|
      next unless subscription.cancelled?

      subscription.update!(status: 'active', cancelled_at: nil, last_synced_at: Time.current)
      record_subscription_event(user, 'uncancelled')
    end
  end

  # PRODUCT_CHANGE は月額↔年額のプラン変更。proration / expires_at の調整は Apple/Stripe 側に任せる。
  def handle_product_change
    with_resolved_subscription do |user, subscription|
      subscription.update!(
        plan_type: detect_plan_type(@event_data['product_id']),
        product_id: @event_data['product_id'],
        last_synced_at: Time.current
      )
      record_subscription_event(user, 'product_changed')
    end
  end

  # user lookup と subscription 取得の共通フロー。
  # 初回購入時は subscription が未保存のことがあるため require_persisted で挙動を切り替える。
  def with_resolved_subscription(require_persisted: true)
    user = find_user
    return notify_unknown_user unless user

    subscription = user.subscription_or_default
    return if require_persisted && !subscription.persisted?

    yield user, subscription
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

  def epoch_ms_to_time(milliseconds)
    return nil if milliseconds.nil?

    Time.zone.at(milliseconds.to_i / 1000)
  end

  # 監査ログに同一 revenuecat_event_id が既に書かれていれば握り潰す（冪等性確保）。
  # event_id は派生イベント（例: recovered）で suffix 付き ID を渡せるよう引数化する。
  def record_subscription_event(user, event_type, event_id: @event_data['id'])
    UserSubscriptionEvent.create!(
      user:,
      subscription: user.subscription,
      event_type:,
      platform: detect_platform(@event_data['store']),
      product_id: @event_data['product_id'],
      period_type: @event_data['period_type'],
      occurred_at: epoch_ms_to_time(@event_data['event_timestamp_ms']) || Time.current,
      raw_payload: @event_data,
      revenuecat_event_id: event_id
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
# rubocop:enable Metrics/ClassLength
