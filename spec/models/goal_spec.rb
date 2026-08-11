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

  describe 'metric_key のバリデーション' do
    it '廃止指標は新規作成できない' do
      goal = build(:goal, user:, metric_key: 'total_swing_count')

      expect(goal).not_to be_valid
      expect(goal.errors[:metric_key]).to be_present
    end

    it '廃止指標の既存目標は編集して保存できる' do
      goal = build(:goal, user:, metric_key: 'total_swing_count')
      goal.save!(validate: false)

      expect(goal.update(title: '編集後のタイトル')).to be(true)
    end

    it '許可リストに無い指標は無効' do
      expect(build(:goal, user:, metric_key: 'unknown_metric')).not_to be_valid
    end
  end

  describe 'メニュー単位指標の practice_menu_id' do
    it 'メニュー回数(menu_practice_amount)は対象メニュー必須' do
      goal = build(:goal, user:, metric_key: 'menu_practice_amount', practice_menu: nil)

      expect(goal).not_to be_valid
      expect(goal.errors[:practice_menu_id]).to be_present
    end

    it 'メニュー継続日数(menu_practice_days)は対象メニュー必須' do
      expect(build(:goal, user:, metric_key: 'menu_practice_days', practice_menu: nil)).not_to be_valid
    end

    it '対象メニューを指定すれば有効' do
      expect(build(:goal, user:, metric_key: 'menu_practice_amount', practice_menu: create(:practice_menu, user:))).to be_valid
    end
  end
end
