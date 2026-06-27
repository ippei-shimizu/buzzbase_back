module RevenueCat
  # event_type から適切な Handler クラスを選んでインスタンス化するファクトリ。
  # 新 event_type 対応時は HANDLERS にエントリを 1 行追加するだけで済む。
  module EventDispatcher
    HANDLERS = {
      'INITIAL_PURCHASE' => Handlers::InitialPurchaseHandler,
      'TRIAL_STARTED' => Handlers::InitialPurchaseHandler,
      'RENEWAL' => Handlers::RenewalHandler,
      'CANCELLATION' => Handlers::CancellationHandler,
      'EXPIRATION' => Handlers::ExpirationHandler,
      'BILLING_ISSUE' => Handlers::BillingIssueHandler,
      'REFUND' => Handlers::RefundHandler,
      'UNCANCELLATION' => Handlers::UncancellationHandler,
      'PRODUCT_CHANGE' => Handlers::ProductChangeHandler
    }.freeze

    module_function

    def handler_for(payload)
      handler_class = HANDLERS.fetch(payload.event_type, Handlers::UnknownEventHandler)
      handler_class.new(payload)
    end
  end
end
