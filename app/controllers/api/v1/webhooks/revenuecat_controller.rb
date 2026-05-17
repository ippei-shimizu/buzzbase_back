module Api
  module V1
    module Webhooks
      # POST /api/v1/webhooks/revenuecat
      # RevenueCat からの Webhook 受信スタブ。
      # 本 Issue ではルートの受け皿のみ用意し、署名検証と payload 解釈・状態遷移は #318 で実装する。
      # スタブ実装でも 401/403 ではなく 200 を返し、RevenueCat 側のリトライ抑止を担保する。
      class RevenuecatController < ApplicationController
        skip_before_action :verify_authenticity_token, raise: false

        # TODO(#318): X-RevenueCat-Signature ヘッダの HMAC 検証 + payload 解釈 + 状態遷移処理を実装する。
        def create
          head :ok
        end
      end
    end
  end
end
