module RevenueCat
  # RevenueCat Webhook が送ってくる JSON の `event` 配下を取り出した値オブジェクト。
  # 文字列キー直アクセスを各所で繰り返すと payload 形式変更時に追随箇所が散らばるため、
  # ここに集約して getter として公開する。
  class WebhookPayload
    def initialize(raw_payload)
      @event = (raw_payload || {})['event'] || {}
    end

    def event_id
      @event['id']
    end

    def event_type
      @event['type']
    end

    def app_user_id
      @event['app_user_id']
    end

    def product_id
      @event['product_id']
    end

    def store
      @event['store']
    end

    def period_type
      @event['period_type']
    end

    def trial?
      period_type == 'TRIAL'
    end

    def event_timestamp
      epoch_ms_to_time(@event['event_timestamp_ms'])
    end

    # RevenueCat payload の `expiration_at_ms` に対応する getter。
    # Subscription モデル側の `expires_at` カラムにそのままマップして使う。
    def expiration_at
      epoch_ms_to_time(@event['expiration_at_ms'])
    end

    # UserSubscriptionEvent#raw_payload に保存する素の Hash を返す。
    def to_h
      @event
    end

    private

    def epoch_ms_to_time(milliseconds)
      return nil if milliseconds.nil?

      Time.zone.at(milliseconds.to_i / 1000)
    end
  end
end
