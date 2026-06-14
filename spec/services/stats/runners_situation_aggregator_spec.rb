# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::RunnersSituationAggregator, type: :service do
  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }

  def create_pa(plate_result_id:, runners_state:, batter_box_number: nil)
    attrs = {
      game_result:, user:, plate_result_id:, runners_state:, is_new_format: true
    }
    attrs[:batter_box_number] = batter_box_number if batter_box_number
    create(:plate_appearance, **attrs)
  end

  describe '#call' do
    context 'when no plate appearances' do
      it 'returns zero母数 without raising' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:at_bats]).to eq(0)
          expect(result[:hits]).to eq(0)
          expect(result[:batting_average]).to eq(0.0)
          expect(result[:home_run]).to eq(0)
        end
      end
    end

    context 'with scoring position plate appearances' do
      before do
        # 得点圏（second, third, first_second, first_third, second_third, bases_loaded）
        create_pa(plate_result_id: 7, runners_state: :second)       # ヒット
        create_pa(plate_result_id: 8, runners_state: :third)        # 二塁打
        create_pa(plate_result_id: 10, runners_state: :bases_loaded) # 本塁打
        create_pa(plate_result_id: 13, runners_state: :first_second) # 三振（凡退）
        # 得点圏外
        create_pa(plate_result_id: 7, runners_state: :no_runner)    # ヒット（除外）
        create_pa(plate_result_id: 7, runners_state: :first)        # ヒット（除外）
      end

      it 'only counts plate_appearances whose runners_state is 2..7' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:at_bats]).to eq(4)
          expect(result[:hits]).to eq(3)
          expect(result[:two_base_hit]).to eq(1)
          expect(result[:three_base_hit]).to eq(0)
          expect(result[:home_run]).to eq(1)
          expect(result[:batting_average]).to eq((3.0 / 4).round(3))
        end
      end
    end

    context 'when only old-format PA exist (runners_state nil)' do
      before do
        # 旧仕様：runners_state が NULL → 対象外
        create(:plate_appearance, game_result:, user:, plate_result_id: 7,
                                  is_new_format: false, runners_state: nil)
      end

      it 'returns母数 0 because the filter excludes NULL runners_state' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:at_bats]).to eq(0)
          expect(result[:hits]).to eq(0)
          expect(result[:batting_average]).to eq(0.0)
        end
      end
    end
  end
end
