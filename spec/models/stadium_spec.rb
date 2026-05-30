require 'rails_helper'

RSpec.describe Stadium, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:prefecture).optional }
    it { is_expected.to belong_to(:created_by_user).class_name('User').optional }
    it { is_expected.to have_many(:match_results).dependent(:nullify) }
  end

  describe 'validations' do
    subject { build(:stadium) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end
end
