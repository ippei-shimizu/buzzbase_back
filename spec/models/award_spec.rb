require 'rails_helper'

RSpec.describe Award, type: :model do
  describe 'associations' do
    it { should have_many(:user_awards).dependent(:destroy) }
    it { should have_many(:users).through(:user_awards) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
  end
end
