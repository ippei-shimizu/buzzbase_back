require 'rails_helper'

RSpec.describe Tournament, type: :model do
  describe 'associations' do
    it { should have_many(:match_results).dependent(:destroy) }
  end
end
