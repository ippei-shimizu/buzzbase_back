require 'rails_helper'

RSpec.describe PlateAppearance, type: :model do
  describe 'associations' do
    it { should belong_to(:game_result) }
    it { should belong_to(:user) }
  end
end
