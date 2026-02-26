require 'rails_helper'

RSpec.describe GameResult, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_one(:match_result).dependent(:destroy) }
    it { is_expected.to have_many(:plate_appearances).dependent(:destroy) }
    it { is_expected.to have_one(:batting_average).dependent(:destroy) }
    it { is_expected.to have_one(:pitching_result).dependent(:destroy) }
  end

  describe '.v2_game_associated_data_user' do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }

    let!(:game_result_with_match) { create(:game_result, user: user) }
    let!(:game_result_without_match) do
      gr = GameResult.create!(user: user)
      # match_result_id is nil by default, skip after(:create) callback
      gr
    end
    let!(:other_user_game_result) { create(:game_result, user: other_user) }

    it 'returns game results only for the specified user' do
      results = described_class.v2_game_associated_data_user(user)
      expect(results.map(&:user_id).uniq).to eq([user.id])
    end

    it 'excludes game results without match_result' do
      results = described_class.v2_game_associated_data_user(user)
      expect(results).not_to include(game_result_without_match)
    end

    it 'returns results in descending order by date_and_time' do
      old_game = create(:game_result, user: user)
      old_game.match_result.update!(date_and_time: 1.month.ago)

      results = described_class.v2_game_associated_data_user(user)
      dates = results.map { |r| r.match_result.date_and_time }
      expect(dates).to eq(dates.sort.reverse)
    end

    it 'returns an ActiveRecord::Relation' do
      results = described_class.v2_game_associated_data_user(user)
      expect(results).to be_a(ActiveRecord::Relation)
    end
  end

  describe '.v2_filtered_game_associated_data_user' do
    let(:user) { create(:user) }

    let!(:game_2024_regular) do
      gr = create(:game_result, user: user)
      gr.match_result.update!(date_and_time: Time.zone.local(2024, 6, 15), match_type: 'regular')
      gr
    end

    let!(:game_2024_open) do
      gr = create(:game_result, user: user)
      gr.match_result.update!(date_and_time: Time.zone.local(2024, 8, 20), match_type: 'open')
      gr
    end

    let!(:game_2023_regular) do
      gr = create(:game_result, user: user)
      gr.match_result.update!(date_and_time: Time.zone.local(2023, 5, 10), match_type: 'regular')
      gr
    end

    it 'filters by year' do
      results = described_class.v2_filtered_game_associated_data_user(user, '2024', '全て')
      expect(results.map(&:id)).to contain_exactly(game_2024_regular.id, game_2024_open.id)
    end

    it 'filters by match_type' do
      results = described_class.v2_filtered_game_associated_data_user(user, '通算', 'regular')
      expect(results.map(&:id)).to contain_exactly(game_2024_regular.id, game_2023_regular.id)
    end

    it 'filters by both year and match_type' do
      results = described_class.v2_filtered_game_associated_data_user(user, '2024', 'regular')
      expect(results.map(&:id)).to contain_exactly(game_2024_regular.id)
    end

    it 'returns all results when year is "通算" and match_type is "全て"' do
      results = described_class.v2_filtered_game_associated_data_user(user, '通算', '全て')
      expect(results.map(&:id)).to contain_exactly(game_2024_regular.id, game_2024_open.id, game_2023_regular.id)
    end
  end

  describe '.v2_all_game_associated_data' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    let!(:game1) { create(:game_result, user: user1) }
    let!(:game2) { create(:game_result, user: user2) }

    it 'returns game results for all users' do
      results = described_class.v2_all_game_associated_data
      expect(results.map(&:id)).to include(game1.id, game2.id)
    end

    it 'excludes game results without match_result' do
      gr_no_match = GameResult.create!(user: user1)
      results = described_class.v2_all_game_associated_data
      expect(results.map(&:id)).not_to include(gr_no_match.id)
    end

    it 'returns results in descending order by date_and_time' do
      game1.match_result.update!(date_and_time: 1.month.ago)
      game2.match_result.update!(date_and_time: Time.current)

      results = described_class.v2_all_game_associated_data
      dates = results.map { |r| r.match_result.date_and_time }
      expect(dates).to eq(dates.sort.reverse)
    end

    it 'returns an ActiveRecord::Relation' do
      results = described_class.v2_all_game_associated_data
      expect(results).to be_a(ActiveRecord::Relation)
    end
  end
end
