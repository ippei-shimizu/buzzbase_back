require 'rails_helper'

RSpec.describe ReflectionTemplate, type: :model do
  let(:user) { create(:user) }

  describe 'バリデーション' do
    it 'title が無いと無効' do
      expect(build(:reflection_template, user:, title: nil)).not_to be_valid
    end

    it 'questions が文字列配列でないと無効' do
      template = build(:reflection_template, user:, questions: [{ a: 1 }])
      expect(template).not_to be_valid
      expect(template.errors[:questions]).to be_present
    end
  end

  describe '.available_for' do
    it 'プリセットと自分の自作を返し、他人の自作は返さない' do
      preset = create(:reflection_template, :preset)
      mine = create(:reflection_template, user:)
      others = create(:reflection_template, user: create(:user))

      ids = described_class.available_for(user).pluck(:id)
      expect(ids).to include(preset.id, mine.id)
      expect(ids).not_to include(others.id)
    end
  end

  describe '既定テンプレの一意性' do
    it '既定を立てると同一ユーザーの他の既定は解除される' do
      first = create(:reflection_template, user:, is_default: true)
      second = create(:reflection_template, user:, is_default: true)
      expect(first.reload.is_default).to be false
      expect(second.reload.is_default).to be true
    end
  end
end
