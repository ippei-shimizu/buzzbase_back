require 'rails_helper'

RSpec.describe NoteTag, type: :model do
  describe '.available_for' do
    let(:user) { create(:user) }
    let!(:preset) { create(:note_tag, :preset, name: '打撃') }
    let!(:mine) { create(:note_tag, user:, name: '自主練') }
    let!(:others) { create(:note_tag, user: create(:user), name: '他人') }

    it '本人の自作とプリセットを返し、他人の自作は含めない' do
      result = described_class.available_for(user)
      expect(result).to include(preset, mine)
      expect(result).not_to include(others)
    end
  end
end
