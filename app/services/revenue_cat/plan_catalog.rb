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
      'jp.buzzbase.mobile.pro.monthly' => 'monthly',
      'jp.buzzbase.mobile.pro.yearly' => 'yearly'
    }.freeze

    module_function

    def plan_type_from(product_id)
      PRODUCT_ID_TO_PLAN_TYPE[product_id] || stripe_plan_type_from(product_id)
    end

    def platform_from(store)
      STORE_TO_PLATFORM[store]
    end

    # StripeのProduct IDはモバイルの固定文字列product_idと異なり、test/liveモードで値が
    # 変わるため、定数ではなくENVで環境ごとに切り替える。
    # product_idがblankの場合に先に弾かないと、STRIPE_PRODUCT_ID_MONTHLY/YEARLYが未設定の
    # 環境ではENV.fetchもnilを返すため、nil == nilで誤って'monthly'と判定してしまう。
    def stripe_plan_type_from(product_id)
      return nil if product_id.blank?
      return 'monthly' if product_id == ENV.fetch('STRIPE_PRODUCT_ID_MONTHLY', nil)
      return 'yearly' if product_id == ENV.fetch('STRIPE_PRODUCT_ID_YEARLY', nil)

      nil
    end
  end
end
