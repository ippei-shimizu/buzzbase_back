module App
  module Stripe
    # Stripe webhook の設定漏れ等、リトライしても回復しない恒久的エラーの共通マーカー。
    # 各 handler の恒久的エラークラスはこれを継承する。App::Stripe::WebhookJob はこの1クラスだけを
    # discard_on すればよく、新しい恒久的エラーを追加する側が個別に job 側の登録を
    # 忘れるリスクを構造的に防ぐ。
    # RevenueCat::PermanentWebhookError とは無関係な別クラスなので、RevenueCat側のhandlerからは継承しないこと。
    class PermanentWebhookError < StandardError; end
  end
end
