require 'rails_helper'

RSpec.describe Team, type: :model do
  describe 'associations' do
    it { should belong_to(:category).class_name('BaseballCategory').optional }
    it { should belong_to(:prefecture).optional }
    it { should have_one(:user).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end
end
