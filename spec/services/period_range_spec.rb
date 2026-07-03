# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PeriodRange, type: :service do
  describe '.parse' do
    it 'parses "YYYY-MM" into [year, month]' do
      aggregate_failures do
        expect(described_class.parse('2025-05')).to eq([2025, 5])
        expect(described_class.parse('2025-12')).to eq([2025, 12])
      end
    end

    it 'returns [nil, nil] for blank / invalid / out-of-range month' do
      aggregate_failures do
        expect(described_class.parse(nil)).to eq([nil, nil])
        expect(described_class.parse('')).to eq([nil, nil])
        expect(described_class.parse('2025-13')).to eq([nil, nil])
        expect(described_class.parse('2025-00')).to eq([nil, nil])
        expect(described_class.parse('2025/05')).to eq([nil, nil])
        expect(described_class.parse('abc')).to eq([nil, nil])
      end
    end
  end

  describe '.parse_start' do
    it 'returns the first moment of the month' do
      expect(described_class.parse_start('2025-05')).to eq(Time.zone.local(2025, 5, 1))
    end

    it 'returns nil for an invalid month' do
      expect(described_class.parse_start('bad')).to be_nil
    end
  end

  describe '.parse_end_exclusive' do
    it 'returns the first moment of the following month' do
      expect(described_class.parse_end_exclusive('2025-07')).to eq(Time.zone.local(2025, 8, 1))
    end

    it 'rolls the year over for December' do
      expect(described_class.parse_end_exclusive('2025-12')).to eq(Time.zone.local(2026, 1, 1))
    end
  end

  describe '.apply' do
    let(:user) { create(:user) }
    let!(:april) { game_on('2025-04-15 12:00') }
    let!(:may_start) { game_on('2025-05-01 00:00') }
    let!(:may_end) { game_on('2025-05-31 23:59') }
    let!(:july) { game_on('2025-07-20 12:00') }
    let!(:august) { game_on('2025-08-01 00:00') }
    let(:scope) { GameResult.joins(:match_result).where(user:) }

    def game_on(datetime)
      game_result = create(:game_result, user:)
      game_result.match_result.update!(date_and_time: Time.zone.parse(datetime))
      game_result
    end

    it 'includes games within the inclusive start / inclusive end month range' do
      ids = described_class.apply(scope, '2025-05', '2025-07').pluck(:id)
      expect(ids).to contain_exactly(may_start.id, may_end.id, july.id)
    end

    it 'includes the last moment of the end month and excludes the next month (datetime boundary)' do
      ids = described_class.apply(scope, '2025-05', '2025-05').pluck(:id)
      aggregate_failures do
        expect(ids).to contain_exactly(may_start.id, may_end.id)
        expect(ids).not_to include(august.id)
      end
    end

    it 'treats a missing end_month as an open upper bound' do
      ids = described_class.apply(scope, '2025-05', nil).pluck(:id)
      expect(ids).to contain_exactly(may_start.id, may_end.id, july.id, august.id)
    end

    it 'treats a missing start_month as an open lower bound' do
      ids = described_class.apply(scope, nil, '2025-05').pluck(:id)
      expect(ids).to contain_exactly(april.id, may_start.id, may_end.id)
    end

    it 'returns the scope unchanged when both bounds are blank' do
      expect(described_class.apply(scope, nil, nil).pluck(:id)).to match_array(scope.pluck(:id))
    end
  end
end
