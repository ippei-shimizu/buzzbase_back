require 'rails_helper'

RSpec.describe Season, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:game_results).dependent(:nullify) }
  end

  describe 'validations' do
    subject { create(:season) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(50) }
    it { should validate_uniqueness_of(:name).scoped_to(:user_id) }
  end
end
