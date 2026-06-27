module RevenueCat
  # RevenueCat の product_id / store 文字列を Subscription enum 値に対応付ける辞書。
  # 商品追加時にここだけ差し替えれば他クラスは変更不要。
  module PlanCatalog
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

    module_function

    def plan_type_from(product_id)
      PRODUCT_ID_TO_PLAN_TYPE[product_id]
    end

    def platform_from(store)
      STORE_TO_PLATFORM[store]
    end
  end
end
