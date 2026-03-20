require 'rails_helper'

RSpec.describe GroupRankingSnapshot, type: :model do
  describe 'associations' do
    it { should belong_to(:group) }
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_inclusion_of(:stat_type).in_array(GroupRankingSnapshot::ALL_STAT_TYPES) }
    it { should validate_numericality_of(:rank).is_greater_than(0) }
    it { should validate_presence_of(:snapshot_date) }
  end

  describe 'scopes' do
    let(:group) { create(:group) }
    let(:user) { create(:user) }
    let!(:snapshot) { create(:group_ranking_snapshot, group:, user:, snapshot_date: Date.current) }
    let!(:other_snapshot) { create(:group_ranking_snapshot) }

    describe '.for_group' do
      it '指定グループのスナップショットのみを返す' do
        expect(described_class.for_group(group.id)).to include(snapshot)
        expect(described_class.for_group(group.id)).not_to include(other_snapshot)
      end
    end

    describe '.for_user' do
      it '指定ユーザーのスナップショットのみを返す' do
        expect(described_class.for_user(user.id)).to include(snapshot)
        expect(described_class.for_user(user.id)).not_to include(other_snapshot)
      end
    end

    describe '.for_date' do
      it '指定日付のスナップショットのみを返す' do
        expect(described_class.for_date(Date.current)).to include(snapshot)
      end
    end
  end

  describe '.latest_for' do
    let(:group) { create(:group) }
    let(:user) { create(:user) }

    it '指定条件で最新のスナップショットを返す' do
      old = create(:group_ranking_snapshot, group:, user:, stat_type: 'batting_average',
                                            snapshot_date: 2.days.ago.to_date)
      latest = create(:group_ranking_snapshot, group:, user:, stat_type: 'batting_average',
                                               snapshot_date: Date.current)

      result = described_class.latest_for(group_id: group.id, user_id: user.id, stat_type: 'batting_average')
      expect(result).to eq(latest)
      expect(result).not_to eq(old)
    end

    it '該当レコードがない場合はnilを返す' do
      result = described_class.latest_for(group_id: group.id, user_id: user.id, stat_type: 'era')
      expect(result).to be_nil
    end
  end
end
