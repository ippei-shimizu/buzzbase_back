require 'rails_helper'

RSpec.describe PeriodicReviews::Generator, type: :service do
  let(:user) { create(:user) }
  let(:period_start) { Time.find_zone('Asia/Tokyo').today.beginning_of_week - 7 }

  describe '#call（週次）' do
    before do
      create(:activity_log, user:, activity_date: period_start, total_swing_count: 300, intensity_level: 2)
      create(:activity_log, user:, activity_date: period_start + 1, total_swing_count: 200, intensity_level: 1)
    end

    it '基本部（練習量・Streak）と詳細部を集計して保存する' do
      review = described_class.new(user:, period_type: 'weekly', period_start:).call
      expect(review).to be_persisted
      expect(review.period_end).to eq(period_start + 6)
      expect(review.summary['practice_days']).to eq(2)
      expect(review.summary['total_swings']).to eq(500)
      expect(review.summary).to have_key('theme_breakdown')
      expect(review.summary).to have_key('batting')
    end

    it '同一期間の再生成は upsert（重複を作らない）' do
      described_class.new(user:, period_type: 'weekly', period_start:).call
      expect do
        described_class.new(user:, period_type: 'weekly', period_start:).call
      end.not_to(change { user.periodic_reviews.count })
    end

    it '取組中の課題を内訳に含める' do
      theme = create(:improvement_theme, user:, status: 'open')
      create(:practice_session, user:, logged_on: period_start, improvement_theme: theme)
      review = described_class.new(user:, period_type: 'weekly', period_start:).call
      breakdown = review.summary['theme_breakdown']
      expect(breakdown.first).to include('title' => theme.title, 'practice_count' => 1)
    end

    it '防御率は試合ごとの inning_format（7回制）で加重し、9固定より低く算出する' do
      game_result = create(:game_result, user:)
      game_result.match_result.update!(date_and_time: period_start.in_time_zone('Asia/Tokyo').noon, inning_format: 7)
      create(:pitching_result, user:, game_result:, innings_pitched: 7.0, earned_run: 7, base_on_balls: 0,
                               hits_allowed: 0, strikeouts: 7)

      review = described_class.new(user:, period_type: 'weekly', period_start:).call

      # 9固定なら (7*9/7)=9.00 になるところ、7回制加重で (7*7/7)=7.00 になる。
      expect(review.summary['pitching']['era']).to eq(7.0)
      expect(review.summary['pitching']['k_per_9']).to eq(7.0)
    end
  end

  describe '#call（月次）' do
    it '月初〜月末を期間として保存する' do
      month_start = Time.find_zone('Asia/Tokyo').today.prev_month.beginning_of_month
      review = described_class.new(user:, period_type: 'monthly', period_start: month_start).call
      expect(review.period_type).to eq('monthly')
      expect(review.period_end).to eq(month_start.end_of_month)
    end

    it '成績の前期間比較は固定日数ではなく前月の暦月（1日を含む）で行う' do
      # 4月（30日）の固定日数方式だと 3/2〜3/31 になり 3/1 の試合が漏れる。
      game_result = create(:game_result, user:)
      game_result.match_result.update!(date_and_time: Time.find_zone('Asia/Tokyo').local(2026, 3, 1, 13, 0))
      create(:batting_average, user:, game_result:, hit: 1, at_bats: 3)

      review = described_class.new(user:, period_type: 'monthly', period_start: Date.new(2026, 4, 1)).call
      expect(review.summary['batting']['previous_batting_average']).to eq(0.333)
    end
  end
end
