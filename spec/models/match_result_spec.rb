require 'rails_helper'

RSpec.describe MatchResult, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:my_team).class_name('Team') }
    it { should belong_to(:opponent_team).class_name('Team') }
    it { should belong_to(:tournament).optional }
    it { should belong_to(:game_result) }
    it { should belong_to(:stadium).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:date_and_time) }
    it { should validate_presence_of(:match_type) }
    it { should validate_presence_of(:my_team_score) }
    it { should validate_presence_of(:opponent_team_score) }
    it { should validate_presence_of(:inning_format) }

    it 'validates inning_format inclusion with the Japanese locale message' do
      expect(described_class.new).to validate_inclusion_of(:inning_format)
        .in_array([7, 9])
        .with_message('は7または9を指定してください')
    end

    # appearance_type に応じた条件付きバリデーション。
    # starter は守備位置のみ必須。打順は DH 制で投手として出場する場合「なし」を許容するため任意。
    # batting_order カラムは DB 上 null: false のため、保存実態は空文字 '' を渡す（リクエストスペックと統一）。
    context 'when appearance_type is starter' do
      it 'allows empty batting_order' do
        mr = build(:match_result, appearance_type: 'starter', batting_order: '')
        expect(mr).to be_valid
      end

      it 'requires defensive_position' do
        mr = build(:match_result, appearance_type: 'starter', defensive_position: nil)
        expect(mr).not_to be_valid
        expect(mr.errors[:defensive_position]).to be_present
      end
    end

    context 'when appearance_type is substitute' do
      it 'allows missing batting_order and defensive_position' do
        mr = build(:match_result,
                   appearance_type: 'substitute',
                   batting_order: nil,
                   defensive_position: nil)
        expect(mr).to be_valid
      end
    end

    context 'when appearance_type is pinch_hitter' do
      it 'allows missing batting_order and defensive_position' do
        mr = build(:match_result,
                   appearance_type: 'pinch_hitter',
                   batting_order: nil,
                   defensive_position: nil)
        expect(mr).to be_valid
      end
    end

    context 'when appearance_type is pinch_runner' do
      it 'allows missing batting_order and defensive_position' do
        mr = build(:match_result,
                   appearance_type: 'pinch_runner',
                   batting_order: nil,
                   defensive_position: nil)
        expect(mr).to be_valid
      end
    end

    context 'when appearance_type is no_play' do
      it 'allows missing batting_order and defensive_position' do
        mr = build(:match_result,
                   appearance_type: 'no_play',
                   batting_order: nil,
                   defensive_position: nil)
        expect(mr).to be_valid
      end
    end

    context 'with an unknown appearance_type' do
      it 'is invalid' do
        mr = build(:match_result, appearance_type: 'unknown')
        expect(mr).not_to be_valid
        expect(mr.errors[:appearance_type]).to be_present
      end
    end
  end

  describe 'APPEARANCE_TYPES' do
    # 値ごとの挙動はバリデーション spec で網羅しているので、ここでは件数だけ守る。
    it 'has 5 entries' do
      expect(described_class::APPEARANCE_TYPES.size).to eq(5)
    end
  end
end
