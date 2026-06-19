# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::BattingFormulas do
  describe '.total_hits' do
    it '単打 + 2B + 3B + HR の合計を返す' do
      expect(described_class.total_hits(singles: 5, doubles: 2, triples: 1, home_runs: 1)).to eq(9)
    end

    it 'すべて 0 のとき 0 を返す' do
      expect(described_class.total_hits(singles: 0, doubles: 0, triples: 0, home_runs: 0)).to eq(0)
    end

    it 'nil を 0 として扱う（nil-safe）' do
      expect(described_class.total_hits(singles: nil, doubles: 2, triples: nil, home_runs: 1)).to eq(3)
    end
  end

  describe '.total_bases' do
    it '単打×1 + 2B×2 + 3B×3 + HR×4 を返す' do
      # 単打 1 + 2B 2 + 3B 1 + HR 1 = 1 + 4 + 3 + 4 = 12
      expect(described_class.total_bases(singles: 1, doubles: 2, triples: 1, home_runs: 1)).to eq(12)
    end

    it 'すべて 0 のとき 0 を返す' do
      expect(described_class.total_bases(singles: 0, doubles: 0, triples: 0, home_runs: 0)).to eq(0)
    end

    it '単打のみのときその数を返す' do
      expect(described_class.total_bases(singles: 5, doubles: 0, triples: 0, home_runs: 0)).to eq(5)
    end

    it '本塁打のみのとき 4 倍を返す' do
      expect(described_class.total_bases(singles: 0, doubles: 0, triples: 0, home_runs: 3)).to eq(12)
    end

    it 'nil を 0 として扱う' do
      expect(described_class.total_bases(singles: nil, doubles: 1, triples: nil, home_runs: nil)).to eq(2)
    end
  end

  describe '.batting_average' do
    it '打率 = 総安打 / 打数 を 3 桁 round で返す' do
      expect(described_class.batting_average(total_hits: 3, at_bats: 10)).to eq(0.3)
    end

    it '打数 0 のとき 0.0 を返す（ゼロ除算ガード）' do
      expect(described_class.batting_average(total_hits: 5, at_bats: 0)).to eq(0.0)
    end

    it '丸めが効く（3/7 = 0.428... → 0.429）' do
      expect(described_class.batting_average(total_hits: 3, at_bats: 7)).to eq((3.0 / 7).round(3))
    end

    it '1.0 を超えるケース（実データはあり得ないが式の挙動として）' do
      expect(described_class.batting_average(total_hits: 11, at_bats: 10)).to eq(1.1)
    end
  end

  describe '.on_base_percentage' do
    it 'OBP = (H + BB + HBP) / (AB + BB + HBP + SF) を返す' do
      # (3 + 2 + 1) / (10 + 2 + 1 + 1) = 6/14 = 0.4285... → 0.429
      result = described_class.on_base_percentage(
        total_hits: 3, base_on_balls: 2, hit_by_pitch: 1, at_bats: 10, sacrifice_fly: 1
      )
      expect(result).to eq((6.0 / 14).round(3))
    end

    it '分母が 0 のとき 0.0 を返す' do
      expect(
        described_class.on_base_percentage(
          total_hits: 0, base_on_balls: 0, hit_by_pitch: 0, at_bats: 0, sacrifice_fly: 0
        )
      ).to eq(0.0)
    end

    it '四球のみのケース（AB=0, BB=2）でも 1.0 を返す' do
      expect(
        described_class.on_base_percentage(
          total_hits: 0, base_on_balls: 2, hit_by_pitch: 0, at_bats: 0, sacrifice_fly: 0
        )
      ).to eq(1.0)
    end

    it 'nil を 0 として扱う' do
      expect(
        described_class.on_base_percentage(
          total_hits: 1, base_on_balls: nil, hit_by_pitch: nil, at_bats: 3, sacrifice_fly: nil
        )
      ).to eq((1.0 / 3).round(3))
    end
  end

  describe '.slugging_percentage' do
    it 'SLG = TB / AB を 3 桁 round で返す' do
      expect(described_class.slugging_percentage(total_bases: 7, at_bats: 10)).to eq(0.7)
    end

    it '打数 0 のとき 0.0 を返す' do
      expect(described_class.slugging_percentage(total_bases: 5, at_bats: 0)).to eq(0.0)
    end

    it 'TB > AB（実データにはあるパターン: 本塁打多め）も正しく返す' do
      expect(described_class.slugging_percentage(total_bases: 15, at_bats: 10)).to eq(1.5)
    end
  end

  describe '.ops' do
    it 'OPS = OBP + SLG を 3 桁 round で返す' do
      expect(described_class.ops(obp: 0.4, slg: 0.7)).to eq(1.1)
    end

    it '両方 0 のとき 0 を返す' do
      expect(described_class.ops(obp: 0.0, slg: 0.0)).to eq(0.0)
    end

    it '丸め誤差の累積を 3 桁で抑える' do
      expect(described_class.ops(obp: 0.4285, slg: 0.7142)).to eq(1.143)
    end
  end

  describe '.iso' do
    it 'ISO = SLG - AVG を 3 桁 round で返す' do
      # SLG 0.7, AVG 0.3 → ISO 0.4
      expect(described_class.iso(slg: 0.7, batting_average: 0.3)).to eq(0.4)
    end

    it '負の値も返せる（実データでは普通起きないが式として）' do
      expect(described_class.iso(slg: 0.2, batting_average: 0.5)).to eq(-0.3)
    end

    it '両方 0 のとき 0 を返す' do
      expect(described_class.iso(slg: 0.0, batting_average: 0.0)).to eq(0.0)
    end
  end

  describe '.isod' do
    it 'ISOD = OBP - AVG を 3 桁 round で返す' do
      expect(described_class.isod(obp: 0.4, batting_average: 0.3)).to eq(0.1)
    end

    it '同じ値のとき 0 を返す' do
      expect(described_class.isod(obp: 0.3, batting_average: 0.3)).to eq(0.0)
    end
  end

  describe '.safe_divide' do
    it '通常の割り算結果を 3 桁 round で返す' do
      expect(described_class.safe_divide(3, 10)).to eq(0.3)
    end

    it '分母 0 のとき 0.0 を返す' do
      expect(described_class.safe_divide(5, 0)).to eq(0.0)
    end

    it '分母 nil のとき 0.0 を返す' do
      expect(described_class.safe_divide(5, nil)).to eq(0.0)
    end

    it '分子 0 のとき 0.0 を返す' do
      expect(described_class.safe_divide(0, 5)).to eq(0.0)
    end

    it '整数演算で誤差が出ない（5.0/3 = 1.666...）' do
      expect(described_class.safe_divide(5, 3)).to eq(1.667)
    end
  end

  describe 'TOTAL_HITS_SQL' do
    let(:user) { create(:user) }

    it '実 DB の SUM 式として Ruby 版 total_hits と同じ値を返す' do
      gr1 = create(:game_result, user:)
      gr1.match_result.update!(date_and_time: Time.zone.local(2026, 5, 1))
      create(:batting_average, game_result: gr1, user:,
                               hit: 2, two_base_hit: 1, three_base_hit: 0, home_run: 1,
                               at_bats: 5, total_bases: 7, times_at_bat: 5)
      gr2 = create(:game_result, user:)
      gr2.match_result.update!(date_and_time: Time.zone.local(2026, 5, 2))
      create(:batting_average, game_result: gr2, user:,
                               hit: 1, two_base_hit: 0, three_base_hit: 1, home_run: 0,
                               at_bats: 3, total_bases: 4, times_at_bat: 3)

      # SQL 版: SUM(hit + 2B + 3B + HR) = (2+1+0+1) + (1+0+1+0) = 4 + 2 = 6
      sql_sum = BattingAverage.where(user_id: user.id)
                              .pick(Arel.sql("SUM(#{Stats::BattingFormulas::TOTAL_HITS_SQL})"))
                              .to_i

      # Ruby 版（モデル経由）
      ruby_sum = BattingAverage.where(user_id: user.id).sum(&:total_hits)

      expect(sql_sum).to eq(6)
      expect(sql_sum).to eq(ruby_sum)
    end
  end
end
