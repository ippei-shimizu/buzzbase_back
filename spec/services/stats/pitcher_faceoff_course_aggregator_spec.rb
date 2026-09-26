# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stats::PitcherFaceoffCourseAggregator, type: :service do
  let(:single_result_id) { Stats::BattingAverageRecalculator::HIT_RESULT_IDS.first } # 7 (単打)
  let(:strikeout_result_id) { 13 } # 三振

  let(:user) { create(:user) }
  let(:game_result) { create(:game_result, user:) }

  def create_pitcher(name, team: nil)
    Pitcher.create!(name:, team:, created_by_user: user)
  end

  def create_pa(pitcher_id:, pitch_course:, plate_result_id:, game: game_result)
    create(:plate_appearance, game_result: game, user:, pitcher_id:, pitch_course:,
                              plate_result_id:, is_new_format: true)
  end

  describe '#call' do
    context 'when no plate appearances' do
      it 'returns empty rows and thresholds' do
        result = described_class.new(user_id: user.id).call

        expect(result).to eq(rows: [], total_target_pa: 0, min_at_bats: 3, min_plate_appearances: 3)
      end
    end

    context 'with recorded courses per pitcher' do
      let(:team) { create(:team, name: '相手高校') }
      let!(:ace) { create_pitcher('エース投手', team:) }
      let!(:rookie) { create_pitcher('新人投手') }
      let!(:onetime) { create_pitcher('1 度だけ投手') }

      before do
        # エース投手: 真ん中 (13) に単打 + 三振、外角低め (19) に三振
        create_pa(pitcher_id: ace.id, pitch_course: 13, plate_result_id: single_result_id)
        create_pa(pitcher_id: ace.id, pitch_course: 13, plate_result_id: strikeout_result_id)
        create_pa(pitcher_id: ace.id, pitch_course: 19, plate_result_id: strikeout_result_id)
        # 新人投手: 内角高め (7) に 4 打席
        4.times { create_pa(pitcher_id: rookie.id, pitch_course: 7, plate_result_id: strikeout_result_id) }
        # 1 度だけ投手: しきい値未満でセレクタに出ない
        create_pa(pitcher_id: onetime.id, pitch_course: 13, plate_result_id: single_result_id)
        # 投手だけ記録されコースが無い PA / コースだけ記録され投手が無い PA は対象外
        create_pa(pitcher_id: ace.id, pitch_course: nil, plate_result_id: single_result_id)
        create_pa(pitcher_id: nil, pitch_course: 13, plate_result_id: single_result_id)
      end

      it 'returns only pitchers at or above the threshold, ordered by plate appearances' do
        result = described_class.new(user_id: user.id).call

        aggregate_failures do
          expect(result[:rows].pluck(:label)).to eq(%w[新人投手 エース投手])
          expect(result[:rows].pluck(:plate_appearances)).to eq([4, 3])
          expect(result[:total_target_pa]).to eq(8)
        end
      end

      it 'aggregates cells per (pitcher, course) with 25 zones' do
        result = described_class.new(user_id: user.id).call
        ace_row = result[:rows].find { |row| row[:id] == ace.id }
        center = ace_row[:zones].find { |zone| zone[:course] == 13 }
        low_outside = ace_row[:zones].find { |zone| zone[:course] == 19 }

        aggregate_failures do
          expect(ace_row[:team_name]).to eq('相手高校')
          expect(ace_row[:zones].length).to eq(25)
          expect(center).to include(at_bats: 2, hits: 1, batting_average: 0.5, is_reliable: false)
          expect(low_outside).to include(at_bats: 1, hits: 0)
          expect(ace_row[:zones].sum { |zone| zone[:plate_appearances] }).to eq(3)
        end
      end
    end

    context "with another user's plate appearances" do
      let!(:pitcher) { create_pitcher('エース投手') }

      before do
        other_user = create(:user)
        other_game = create(:game_result, user: other_user)
        3.times do
          create(:plate_appearance, game_result: other_game, user: other_user, pitcher_id: pitcher.id,
                                    pitch_course: 13, plate_result_id: single_result_id, is_new_format: true)
        end
      end

      it 'does not count them' do
        result = described_class.new(user_id: user.id).call

        expect(result[:rows]).to eq([])
      end
    end

    context 'with year filter' do
      let!(:pitcher) { create_pitcher('エース投手') }

      before do
        old_game = create(:game_result, user:)
        old_game.match_result.update!(date_and_time: Time.zone.parse('2025-09-30'))
        create_pa(pitcher_id: pitcher.id, pitch_course: 13, plate_result_id: single_result_id, game: old_game)

        new_game = create(:game_result, user:)
        new_game.match_result.update!(date_and_time: Time.zone.parse('2026-04-01'))
        3.times { create_pa(pitcher_id: pitcher.id, pitch_course: 13, plate_result_id: strikeout_result_id, game: new_game) }
      end

      it 'only counts plate_appearances within the year' do
        result = described_class.new(user_id: user.id, year: 2026).call

        aggregate_failures do
          expect(result[:total_target_pa]).to eq(3)
          expect(result[:rows].first[:plate_appearances]).to eq(3)
        end
      end
    end
  end
end
