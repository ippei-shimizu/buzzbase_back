require 'rails_helper'

RSpec.describe Goal, type: :model do
  let(:user) { create(:user) }

  describe 'target_value のバリデーション' do
    it '負の目標値は無効' do
      goal = build(:goal, user:, target_value: -1)

      aggregate_failures do
        expect(goal).not_to be_valid
        expect(goal.errors[:target_value]).to include('は0以上で入力してください')
      end
    end

    it '0 は有効（達成済みを起点にする目標を許容する）' do
      expect(build(:goal, user:, target_value: 0)).to be_valid
    end

    it '未入力は無効' do
      goal = build(:goal, user:, target_value: nil)

      expect(goal).not_to be_valid
      expect(goal.errors[:target_value]).to be_present
    end

    it '定性目標は目標値を持たなくてよい' do
      expect(build(:goal, :qualitative, user:)).to be_valid
    end
  end
end
