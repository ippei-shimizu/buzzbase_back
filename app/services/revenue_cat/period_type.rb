module RevenueCat
  # RevenueCatのperiod_typeは、Webhookペイロードでは大文字("TRIAL")、
  # REST API（GET /v1/subscribers）レスポンスでは小文字("trial")で届く。
  # データソースごとに独立して比較ロジックを持つと表記ゆれを見落としやすいため、
  # 判定をここに集約する（WebhookPayload#trial? / SubscriberSync双方から参照する）。
  module PeriodType
    module_function

    def trial?(raw_value)
      raw_value.to_s.casecmp?('TRIAL')
    end
  end
end
