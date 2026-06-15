# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::ContactQualityAggregator, type: :service do
  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }

  def create_pa(contact_quality_id:, batter_box_number: nil)
    attrs = { game_result:, user:, contact_quality_id:, is_new_format: true }
    attrs[:batter_box_number] = batter_box_number if batter_box_number
    create(:plate_appearance, **attrs)
  end

  describe '#call' do
    context 'when no plate appearances' do
      it 'returns all 5 master categories with zero count and total 0' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:total]).to eq(0)
          expect(result[:breakdown].pluck(:label))
            .to contain_exactly('真芯', '先っぽ', '詰まり', '擦り', 'ドライブ')
          expect(result[:breakdown].pluck(:count)).to all(eq(0))
          expect(result[:breakdown].pluck(:percentage)).to all(eq(0.0))
        end
      end

      it 'orders breakdown by display_order' do
        result = described_class.new(user_id: user.id).call

        expect(result[:breakdown].pluck(:label))
          .to eq(%w[真芯 先っぽ 詰まり 擦り ドライブ])
      end
    end

    context 'with mixed contact_qualities' do
      before do
        create_pa(contact_quality_id: 1) # 真芯
        create_pa(contact_quality_id: 1) # 真芯
        create_pa(contact_quality_id: 3) # 詰まり
        # contact_quality_id NULL の旧 PA は対象外
        create(:plate_appearance, game_result:, user:, batter_box_number: 99,
                                  contact_quality_id: nil, is_new_format: false)
      end

      it 'aggregates count / percentage for each master entry, excluding NULL' do
        result = described_class.new(user_id: user.id).call

        true_core = result[:breakdown].find { |b| b[:label] == '真芯' }
        jammed = result[:breakdown].find { |b| b[:label] == '詰まり' }
        tip = result[:breakdown].find { |b| b[:label] == '先っぽ' }
        aggregate_failures do
          expect(result[:total]).to eq(3)
          expect(true_core[:count]).to eq(2)
          expect(true_core[:percentage]).to eq(66.7)
          expect(jammed[:count]).to eq(1)
          expect(jammed[:percentage]).to eq(33.3)
          expect(tip[:count]).to eq(0)
        end
      end
    end

    context 'with year filter' do
      before do
        old_game = create(:game_result, user:)
        old_game.match_result.update!(date_and_time: Time.zone.parse('2025-09-30'))
        create(:plate_appearance, game_result: old_game, user:, batter_box_number: 1,
                                  contact_quality_id: 1, is_new_format: true)

        new_game = create(:game_result, user:)
        new_game.match_result.update!(date_and_time: Time.zone.parse('2026-04-01'))
        create(:plate_appearance, game_result: new_game, user:, batter_box_number: 1,
                                  contact_quality_id: 3, is_new_format: true)
      end

      it 'only counts plate_appearances within the year' do
        result = described_class.new(user_id: user.id, year: 2026).call
        jammed = result[:breakdown].find { |b| b[:label] == '詰まり' }

        aggregate_failures do
          expect(result[:total]).to eq(1)
          expect(jammed[:count]).to eq(1)
        end
      end
    end
  end
end
