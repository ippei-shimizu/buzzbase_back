module RevenueCat
  # RevenueCat webhook の設定漏れ等、リトライしても回復しない恒久的エラーの共通マーカー。
  # 各 handler の恒久的エラークラスはこれを継承する。RevenueCatWebhookJob はこの1クラスだけを
  # discard_on すればよく、新しい恒久的エラーを追加する側が個別に job 側の登録を
  # 忘れるリスクを構造的に防ぐ。
  class PermanentWebhookError < StandardError; end
end
