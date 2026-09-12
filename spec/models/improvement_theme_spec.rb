require 'rails_helper'

RSpec.describe ImprovementTheme, type: :model do
  let(:user) { create(:user) }

  describe 'バリデーション' do
    it 'title が無いと無効' do
      theme = build(:improvement_theme, user:, title: nil)
      expect(theme).not_to be_valid
      expect(theme.errors[:title]).to be_present
    end

    it '未知の category は無効' do
      theme = build(:improvement_theme, user:, category: 'unknown')
      expect(theme).not_to be_valid
    end

    it 'started_on は作成時に自動補完される' do
      theme = described_class.create!(user:, title: 'インコースをさばく', started_on: nil)
      expect(theme.started_on).to eq(Time.find_zone('Asia/Tokyo').today)
    end
  end

  describe '#achieve!' do
    it 'status を achieved にして達成日を記録する' do
      theme = create(:improvement_theme, user:)
      theme.achieve!
      expect(theme.reload).to be_achieved
      expect(theme.achieved_on).to eq(Time.find_zone('Asia/Tokyo').today)
    end
  end

  describe '取組サマリー' do
    let(:theme) { create(:improvement_theme, user:) }
    let(:menu) { create(:practice_menu, user:) }

    it '紐付く練習・ノート・取組日数を集計する' do
      today = Time.find_zone('Asia/Tokyo').today
      session = create(:practice_session, user:, logged_on: today, improvement_theme: theme)
      create(:practice_log, user:, practice_session: session, practice_menu: menu, logged_on: today)
      create(:baseball_note, user:, improvement_theme: theme)

      expect(theme.practice_logs_count).to eq(1)
      expect(theme.notes_count).to eq(1)
      expect(theme.active_days).to eq(1)
    end
  end
end
