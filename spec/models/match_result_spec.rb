require 'rails_helper'

RSpec.describe MatchResult, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:my_team).class_name('Team') }
    it { should belong_to(:opponent_team).class_name('Team') }
    it { should belong_to(:tournament).optional }
    it { should belong_to(:game_result) }
  end

  describe 'validations' do
    it { should validate_presence_of(:date_and_time) }
    it { should validate_presence_of(:match_type) }
    it { should validate_presence_of(:my_team_score) }
    it { should validate_presence_of(:opponent_team_score) }
    it { should validate_presence_of(:batting_order) }
    it { should validate_presence_of(:defensive_position) }
  end
end
