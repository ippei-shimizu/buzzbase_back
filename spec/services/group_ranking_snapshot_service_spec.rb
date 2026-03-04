require 'rails_helper'

RSpec.describe GroupRankingSnapshotService do
  let(:group) { Group.create!(name: 'テストグループ') }
  let(:user_a) { create(:user) }
  let(:user_b) { create(:user) }
  let(:snapshot_date) { Date.current }

  before do
    GroupInvitation.create!(user: user_a, group:, state: 'accepted', sent_at: Time.current)
    GroupInvitation.create!(user: user_b, group:, state: 'accepted', sent_at: Time.current)
  end

  describe '#record' do
    context 'with batting stats' do
      before do
        # user_a: 打率 .400 (4/10), 本塁打2, 打点5
        gr_a = create(:game_result, user: user_a)
        create(:batting_average, game_result: gr_a, user: user_a,
                                 hit: 4, at_bats: 10, times_at_bat: 12, home_run: 2, runs_batted_in: 5,
                                 two_base_hit: 0, three_base_hit: 0, base_on_balls: 2, stealing_base: 1)

        # user_b: 打率 .300 (3/10), 本塁打3, 打点4
        gr_b = create(:game_result, user: user_b)
        create(:batting_average, game_result: gr_b, user: user_b,
                                 hit: 3, at_bats: 10, times_at_bat: 11, home_run: 3, runs_batted_in: 4,
                                 two_base_hit: 0, three_base_hit: 0, base_on_balls: 1, stealing_base: 0)
      end

      it 'creates ranking snapshots for each batting stat type' do
        expect { described_class.new(group, snapshot_date).record }
          .to change(GroupRankingSnapshot, :count)
          .by(GroupRankingSnapshot::BATTING_STAT_TYPES.size * 2)
      end

      it 'ranks users correctly for batting_average (higher is better)' do
        described_class.new(group, snapshot_date).record

        rank_a = GroupRankingSnapshot.find_by(group:, user: user_a, stat_type: 'batting_average')
        rank_b = GroupRankingSnapshot.find_by(group:, user: user_b, stat_type: 'batting_average')

        # user_a (.400) > user_b (.300) => user_a is rank 1
        expect(rank_a.rank).to eq(1)
        expect(rank_b.rank).to eq(2)
      end

      it 'ranks users correctly for home_run' do
        described_class.new(group, snapshot_date).record

        rank_a = GroupRankingSnapshot.find_by(group:, user: user_a, stat_type: 'home_run')
        rank_b = GroupRankingSnapshot.find_by(group:, user: user_b, stat_type: 'home_run')

        # user_b (3) > user_a (2) => user_b is rank 1
        expect(rank_b.rank).to eq(1)
        expect(rank_a.rank).to eq(2)
      end
    end

    context 'with pitching stats' do
      before do
        # user_a: ERA 2.0 (2ER/9IP), 勝1
        gr_a = create(:game_result, user: user_a)
        create(:pitching_result, game_result: gr_a, user: user_a,
                                 win: 1, loss: 0, innings_pitched: 9.0, earned_run: 2,
                                 strikeouts: 8, base_on_balls: 1, hits_allowed: 4)

        # user_b: ERA 3.0 (3ER/9IP), 勝2
        gr_b1 = create(:game_result, user: user_b)
        create(:pitching_result, game_result: gr_b1, user: user_b,
                                 win: 1, loss: 0, innings_pitched: 6.0, earned_run: 2,
                                 strikeouts: 5, base_on_balls: 2, hits_allowed: 5)
        gr_b2 = create(:game_result, user: user_b)
        create(:pitching_result, game_result: gr_b2, user: user_b,
                                 win: 1, loss: 0, innings_pitched: 3.0, earned_run: 1,
                                 strikeouts: 3, base_on_balls: 0, hits_allowed: 2)
      end

      it 'ranks ERA in ascending order (lower is better)' do
        described_class.new(group, snapshot_date).record

        rank_a = GroupRankingSnapshot.find_by(group:, user: user_a, stat_type: 'era')
        rank_b = GroupRankingSnapshot.find_by(group:, user: user_b, stat_type: 'era')

        # user_a ERA 2.0 < user_b ERA 3.0 => user_a is rank 1
        expect(rank_a.rank).to eq(1)
        expect(rank_b.rank).to eq(2)
      end

      it 'ranks win in descending order (higher is better)' do
        described_class.new(group, snapshot_date).record

        rank_a = GroupRankingSnapshot.find_by(group:, user: user_a, stat_type: 'win')
        rank_b = GroupRankingSnapshot.find_by(group:, user: user_b, stat_type: 'win')

        # user_b (2 wins) > user_a (1 win) => user_b is rank 1
        expect(rank_b.rank).to eq(1)
        expect(rank_a.rank).to eq(2)
      end
    end

    context 'when group has no members' do
      let(:empty_group) { Group.create!(name: '空グループ') }

      it 'does nothing' do
        expect { described_class.new(empty_group, snapshot_date).record }
          .not_to change(GroupRankingSnapshot, :count)
      end
    end

    context 'when a member has no stats' do
      before do
        # user_a has stats, user_b does not
        gr = create(:game_result, user: user_a)
        create(:batting_average, game_result: gr, user: user_a,
                                 hit: 3, at_bats: 10, times_at_bat: 10)
      end

      it 'creates snapshots only for users with stats' do
        described_class.new(group, snapshot_date).record

        snapshots_a = GroupRankingSnapshot.where(group:, user: user_a)
        snapshots_b = GroupRankingSnapshot.where(group:, user: user_b)

        expect(snapshots_a.count).to be > 0
        expect(snapshots_b.count).to eq(0)
      end
    end

    context 'when recording on the same date again' do
      before do
        gr = create(:game_result, user: user_a)
        create(:batting_average, game_result: gr, user: user_a,
                                 hit: 3, at_bats: 10, times_at_bat: 10)
      end

      it 'updates existing snapshots instead of creating duplicates' do
        described_class.new(group, snapshot_date).record
        initial_count = GroupRankingSnapshot.count

        described_class.new(group, snapshot_date).record
        expect(GroupRankingSnapshot.count).to eq(initial_count)
      end
    end
  end

  describe '.record_all' do
    let(:group2) { Group.create!(name: 'グループ2') }
    let(:user_c) { create(:user) }

    before do
      GroupInvitation.create!(user: user_c, group: group2, state: 'accepted', sent_at: Time.current)

      gr_a = create(:game_result, user: user_a)
      create(:batting_average, game_result: gr_a, user: user_a, hit: 3, at_bats: 10, times_at_bat: 10)

      gr_c = create(:game_result, user: user_c)
      create(:batting_average, game_result: gr_c, user: user_c, hit: 2, at_bats: 8, times_at_bat: 8)
    end

    it 'records snapshots for all groups' do
      described_class.record_all(date: snapshot_date)

      expect(GroupRankingSnapshot.where(group:).count).to be > 0
      expect(GroupRankingSnapshot.where(group: group2).count).to be > 0
    end
  end
end
