# 早期特典窓を含むトライアル日数判定の単一ソース。
# Webhook handler / Stripe Checkout の双方から参照されるため、副作用のないクラスメソッドのみ提供する。
class TrialDaysCalculator
  # Pro リリース日（2026-05-31）から 7 日間の早期特典窓。
  # リリース日が後ろ倒しになる可能性があるため、確定までは ENV
  # (EARLY_SUBSCRIBER_WINDOW_START / END) で実環境ごとに override する運用とし、
  # 最終リリース日が決まった段階で本定数を更新する。
  DEFAULT_WINDOW_START = '2026-05-31 00:00:00 +0900'.freeze
  DEFAULT_WINDOW_END   = '2026-06-06 23:59:59 +0900'.freeze
  NORMAL_TRIAL_DAYS = 7
  EARLY_TRIAL_DAYS  = 30

  # 与えられたユーザーの「今回適用すべきトライアル日数」を返す。
  # 再加入（has_used_trial=true）は仕様で 0 固定とする。
  # @return [Integer] 0 / 7 / 30
  def self.for(user, at: Time.current)
    return 0 if user.subscription&.has_used_trial?

    in_early_window?(at) ? EARLY_TRIAL_DAYS : NORMAL_TRIAL_DAYS
  end

  # 早期特典窓内かを判定する。窓は ENV で override 可能（緊急時に運営が前後に伸ばすため）。
  # @param at [Time] 判定対象の時刻
  # @return [Boolean]
  def self.in_early_window?(at = Time.current)
    window_start = Time.zone.parse(ENV.fetch('EARLY_SUBSCRIBER_WINDOW_START', DEFAULT_WINDOW_START))
    window_end   = Time.zone.parse(ENV.fetch('EARLY_SUBSCRIBER_WINDOW_END', DEFAULT_WINDOW_END))
    at.between?(window_start, window_end)
  end
end
