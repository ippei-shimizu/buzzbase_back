# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::PitchCourseAggregator, type: :service do
  # plate_result_id の SSoT は Stats::BattingAverageRecalculator::HIT_RESULT_IDS。
  let(:single_result_id) { Stats::BattingAverageRecalculator::HIT_RESULT_IDS.first } # 7 (単打)
  let(:strikeout_result_id) { 13 } # 三振
  let(:walk_result_id) { Stats::BattingAverageRecalculator::BASE_ON_BALLS_ID } # 15 (四球)

  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }

  def create_pa(pitch_course:, plate_result_id:, is_new_format: true)
    create(:plate_appearance, game_result:, user:, pitch_course:, plate_result_id:, is_new_format:)
  end

  describe '#call' do
    context 'when no plate appearances' do
      it 'returns all 25 zones with zero stats and total_target_pa 0' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:zones].length).to eq(25)
          expect(result[:zones].pluck(:at_bats)).to all(eq(0))
          expect(result[:zones].pluck(:batting_average)).to all(eq(0.0))
          expect(result[:zones].pluck(:is_reliable)).to all(be(false))
          expect(result[:total_target_pa]).to eq(0)
          expect(result[:min_at_bats]).to eq(3)
        end
      end

      it 'computes row / col / is_strike_zone from the course number' do
        result = described_class.new(user_id: user.id).call
        course1 = result[:zones].find { |z| z[:course] == 1 }
        course13 = result[:zones].find { |z| z[:course] == 13 }
        course25 = result[:zones].find { |z| z[:course] == 25 }

        aggregate_failures do
          expect(course1).to include(row: 1, col: 1, is_strike_zone: false)
          expect(course13).to include(row: 3, col: 3, is_strike_zone: true)
          expect(course25).to include(row: 5, col: 5, is_strike_zone: false)
          expect(result[:zones].count { |z| z[:is_strike_zone] }).to eq(9)
        end
      end
    end

    context 'with recorded courses' do
      before do
        # 真ん中 (13): 単打 + 三振 = 2打数1安打
        create_pa(pitch_course: 13, plate_result_id: single_result_id)
        create_pa(pitch_course: 13, plate_result_id: strikeout_result_id)
        # 外周 (1): 四球のみ = PA 1 / 打数 0
        create_pa(pitch_course: 1, plate_result_id: walk_result_id)
        # pitch_course NULL は対象外
        create(:plate_appearance, game_result:, user:, pitch_course: nil,
                                  plate_result_id: single_result_id, is_new_format: true)
      end

      it 'aggregates at_bats / hits / batting_average per course' do
        result = described_class.new(user_id: user.id).call
        center = result[:zones].find { |z| z[:course] == 13 }
        corner = result[:zones].find { |z| z[:course] == 1 }

        aggregate_failures do
          expect(result[:total_target_pa]).to eq(3)
          expect(center).to include(plate_appearances: 2, at_bats: 2, hits: 1, batting_average: 0.5)
          expect(corner).to include(plate_appearances: 1, at_bats: 0, hits: 0, batting_average: 0.0)
        end
      end

      it 'strike_zone / ball_zone summaries equal the sum of their zones' do
        result = described_class.new(user_id: user.id).call
        strike_zones = result[:zones].select { |z| z[:is_strike_zone] }
        ball_zones = result[:zones].reject { |z| z[:is_strike_zone] }

        aggregate_failures do
          expect(result[:strike_zone][:plate_appearances]).to eq(strike_zones.sum { |z| z[:plate_appearances] })
          expect(result[:strike_zone][:at_bats]).to eq(strike_zones.sum { |z| z[:at_bats] })
          expect(result[:strike_zone][:hits]).to eq(strike_zones.sum { |z| z[:hits] })
          expect(result[:ball_zone][:plate_appearances]).to eq(ball_zones.sum { |z| z[:plate_appearances] })
          expect(result[:strike_zone][:plate_appearances] + result[:ball_zone][:plate_appearances])
            .to eq(result[:total_target_pa])
        end
      end

      it 'excludes 旧形式 (is_new_format: false) の PA' do
        create_pa(pitch_course: 13, plate_result_id: single_result_id, is_new_format: false)

        result = described_class.new(user_id: user.id).call
        center = result[:zones].find { |z| z[:course] == 13 }

        expect(center[:plate_appearances]).to eq(2)
      end
    end

    context 'with is_reliable boundary (MIN_AT_BATS = 3)' do
      it 'marks at_bats 2 as not reliable and at_bats 3 as reliable' do
        2.times { create_pa(pitch_course: 7, plate_result_id: strikeout_result_id) }
        3.times { create_pa(pitch_course: 19, plate_result_id: strikeout_result_id) }

        result = described_class.new(user_id: user.id).call
        two_ab = result[:zones].find { |z| z[:course] == 7 }
        three_ab = result[:zones].find { |z| z[:course] == 19 }

        aggregate_failures do
          expect(two_ab).to include(at_bats: 2, is_reliable: false)
          expect(three_ab).to include(at_bats: 3, is_reliable: true)
        end
      end
    end

    context 'with year filter' do
      before do
        old_game = create(:game_result, user:)
        old_game.match_result.update!(date_and_time: Time.zone.parse('2025-09-30'))
        create(:plate_appearance, game_result: old_game, user:, pitch_course: 13,
                                  plate_result_id: single_result_id, is_new_format: true)

        new_game = create(:game_result, user:)
        new_game.match_result.update!(date_and_time: Time.zone.parse('2026-04-01'))
        create(:plate_appearance, game_result: new_game, user:, pitch_course: 13,
                                  plate_result_id: strikeout_result_id, is_new_format: true)
      end

      it 'only counts plate_appearances within the year' do
        result = described_class.new(user_id: user.id, year: 2026).call
        center = result[:zones].find { |z| z[:course] == 13 }

        aggregate_failures do
          expect(result[:total_target_pa]).to eq(1)
          expect(center).to include(plate_appearances: 1, hits: 0)
        end
      end
    end

    context 'with match_type filter' do
      before do
        game_result.match_result.update!(match_type: 'regular')
        create_pa(pitch_course: 13, plate_result_id: single_result_id)

        practice_game = create(:game_result, user:)
        practice_game.match_result.update!(match_type: 'practice')
        create(:plate_appearance, game_result: practice_game, user:, pitch_course: 13,
                                  plate_result_id: single_result_id, is_new_format: true)
      end

      it 'only counts plate_appearances of the match_type' do
        result = described_class.new(user_id: user.id, match_type: 'regular').call
        expect(result[:total_target_pa]).to eq(1)
      end
    end
  end
end
