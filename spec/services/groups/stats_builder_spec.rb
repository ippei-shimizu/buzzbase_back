# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Groups::StatsBuilder, type: :service do
  describe '#call' do
    describe 'available_years' do
      it 'returns years based on JST, not UTC' do
        user = create(:user)
        game_result = create(:game_result, user:)
        # UTC 2025-12-31 18:00 = JST 2026-01-01 03:00。UTCのままEXTRACTすると前年(2025)にずれる
        game_result.match_result.update!(date_and_time: Time.zone.parse('2026-01-01 03:00:00 +0900'))

        result = described_class.new(accepted_users: [user]).call

        expect(result[:available_years]).to include(2026)
        expect(result[:available_years]).not_to include(2025)
      end
    end
  end
end
