# frozen_string_literal: true

module Stats
  # 投球率指標の単一情報源 (SSoT)。丸め桁（ERA は 2 桁、他は 3 桁）もここで決める。
  #
  # ERA / K/9 / BB/9 の分子は試合ごとのイニング制（match_results.inning_format）で加重した合計を渡す。
  module PitchingFormulas
    # 集計行の累計値から ERA / WHIP / K/9 / BB/9 / K/BB / 勝率 をまとめて計算する。
    # @param innings [Float] 丸める前の投球回合計（1/3 回は 0.333...）
    # @return [Hash{Symbol=>Float}] 分母 0 の指標は 0.0
    def self.rates(weighted_earned_run:, weighted_strikeouts:, weighted_base_on_balls:, # rubocop:disable Metrics/ParameterLists
                   strikeouts:, base_on_balls:, hits_allowed:, win:, loss:, innings:)
      {
        era: era(weighted_earned_run:, innings:),
        whip: whip(base_on_balls:, hits_allowed:, innings:),
        k_per_nine: per_nine(weighted_count: weighted_strikeouts, innings:),
        bb_per_nine: per_nine(weighted_count: weighted_base_on_balls, innings:),
        k_bb: k_bb(strikeouts:, base_on_balls:),
        win_percentage: win_percentage(win:, loss:)
      }
    end

    # 防御率 = Σ(自責点 × イニング制) / 投球回
    def self.era(weighted_earned_run:, innings:)
      safe_divide(weighted_earned_run, innings, 2)
    end

    # WHIP = (与四球 + 被安打) / 投球回
    def self.whip(base_on_balls:, hits_allowed:, innings:)
      safe_divide(base_on_balls.to_i + hits_allowed.to_i, innings)
    end

    # K/9・BB/9 = Σ(奪三振 or 与四球 × イニング制) / 投球回
    def self.per_nine(weighted_count:, innings:)
      safe_divide(weighted_count, innings)
    end

    # K/BB = 奪三振 / 与四球
    def self.k_bb(strikeouts:, base_on_balls:)
      safe_divide(strikeouts, base_on_balls)
    end

    # 勝率 = 勝利 / (勝利 + 敗戦)
    def self.win_percentage(win:, loss:)
      safe_divide(win, win.to_i + loss.to_i)
    end

    # @return [Float] 分母が nil / 0 のときは 0.0
    def self.safe_divide(numerator, denominator, precision = 3)
      return 0.0 if denominator.to_f.zero?

      (numerator.to_f / denominator).round(precision)
    end
  end
end
