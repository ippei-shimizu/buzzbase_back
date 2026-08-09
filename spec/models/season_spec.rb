require 'rails_helper'

RSpec.describe Season, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:game_results).dependent(:nullify) }
    it { should have_many(:goals).dependent(:nullify) }
  end

  describe 'validations' do
    subject { create(:season) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(50) }
    it { should validate_uniqueness_of(:name).scoped_to(:user_id) }
  end

  describe '#destroy' do
    let(:user) { create(:user) }
    let(:season) { create(:season, user:) }

    def season_goal(user:, season:, is_finalized:)
      create(:goal, user:, season:, period_type: 'season', month_start: nil, is_finalized:)
    end

    it '進行中のシーズン目標が紐づいている場合は削除できない' do
      season_goal(user:, season:, is_finalized: false)

      aggregate_failures do
        expect(season.destroy).to be false
        expect(season.errors.full_messages).to include('進行中のシーズン目標が紐づいているため削除できません')
        expect(described_class.exists?(season.id)).to be true
      end
    end

    it '確定済みのシーズン目標だけなら削除でき、目標の紐付けは外れる' do
      goal = season_goal(user:, season:, is_finalized: true)

      aggregate_failures do
        expect(season.destroy).to be_truthy
        expect(goal.reload.season_id).to be_nil
      end
    end

    it 'シーズン目標が紐づいていなければ削除できる' do
      expect(season.destroy).to be_truthy
    end
  end
end
