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
  end

  describe '#call（月次）' do
    it '月初〜月末を期間として保存する' do
      month_start = Time.find_zone('Asia/Tokyo').today.prev_month.beginning_of_month
      review = described_class.new(user:, period_type: 'monthly', period_start: month_start).call
      expect(review.period_type).to eq('monthly')
      expect(review.period_end).to eq(month_start.end_of_month)
    end
  end
end
