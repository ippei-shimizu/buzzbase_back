# frozen_string_literal: true

module Stats
  # 打撃集計式の単一情報源 (SSoT)。
  #
  # `batting_averages.hit` カラムは「単打のみ」を保持する semantics のため、
  # 画面に出す「安打 (NPB 標準 H)」と DB 列の `hit` は別物。本モジュールの
  # `total_hits` を通すことで、Ruby 側でも SQL 側でも揃った計算ができる。
  #
  # 新規 Aggregator / Service / Controller は **必ず本モジュールの関数を経由** し、
  # 独自に再計算しないこと。新しい指標を追加する場合も本モジュールに追加する。
  module BattingFormulas
    # SQL フラグメント。`SUM(...)` で囲って AS hit / AS total_hits に使う。
    # NPB 標準の安打 = 単打 + 二塁打 + 三塁打 + 本塁打。
    TOTAL_HITS_SQL = '(hit + two_base_hit + three_base_hit + home_run)'

    # 全安打 = 単打 + 二塁打 + 三塁打 + 本塁打
    def self.total_hits(singles:, doubles:, triples:, home_runs:)
      singles.to_i + doubles.to_i + triples.to_i + home_runs.to_i
    end

    # 塁打 (TB) = 単打 + 2×二塁打 + 3×三塁打 + 4×本塁打
    def self.total_bases(singles:, doubles:, triples:, home_runs:)
      singles.to_i + (doubles.to_i * 2) + (triples.to_i * 3) + (home_runs.to_i * 4)
    end

    # 打率 = 総安打 / 打数
    def self.batting_average(total_hits:, at_bats:)
      safe_divide(total_hits, at_bats)
    end

    # 出塁率 = (総安打 + 四球 + 死球) / (打数 + 四球 + 死球 + 犠飛)
    def self.on_base_percentage(total_hits:, base_on_balls:, hit_by_pitch:,
                                at_bats:, sacrifice_fly:)
      numer = total_hits.to_i + base_on_balls.to_i + hit_by_pitch.to_i
      denom = at_bats.to_i + base_on_balls.to_i + hit_by_pitch.to_i + sacrifice_fly.to_i
      safe_divide(numer, denom)
    end

    # 長打率 = 塁打 / 打数
    def self.slugging_percentage(total_bases:, at_bats:)
      safe_divide(total_bases, at_bats)
    end

    # OPS = 出塁率 + 長打率
    def self.ops(obp:, slg:)
      (obp.to_f + slg.to_f).round(3)
    end

    # ISO (純粋な長打力) = 長打率 - 打率
    def self.iso(slg:, batting_average:)
      (slg.to_f - batting_average.to_f).round(3)
    end

    # ISOD (純粋な選球眼) = 出塁率 - 打率
    def self.isod(obp:, batting_average:)
      (obp.to_f - batting_average.to_f).round(3)
    end

    # ゼロ除算を 0.0 に丸めて 3 桁 round。各レイヤーで自前実装していた
    # safe_divide を本モジュールに集約する。
    def self.safe_divide(numerator, denominator)
      return 0.0 if denominator.to_i.zero?

      (numerator.to_f / denominator).round(3)
    end
  end
end
