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

  describe '.seed_presets!' do
    it 'プリセットが1件も無い環境で PRESETS を投入する' do
      described_class.presets.delete_all

      expect { described_class.seed_presets! }
        .to change { described_class.presets.count }.from(0).to(described_class::PRESETS.size)
      expect(described_class.presets.pluck(:title)).to match_array(described_class::PRESETS.pluck(:title))
    end

    it '二重実行しても重複を作らず、questions を正本へ揃える' do
      described_class.seed_presets!
      described_class.presets.first.update!(questions: ['書き換えられた問い'])

      expect { described_class.seed_presets! }.not_to(change { described_class.presets.count })
      expect(described_class.presets.ordered.first.questions).to eq(described_class::PRESETS.first[:questions])
    end

    it 'ユーザーの自作テンプレには影響しない' do
      mine = create(:reflection_template, user:, title: described_class::PRESETS.first[:title],
                                          questions: %w[自分の問い])

      described_class.seed_presets!

      expect(mine.reload.questions).to eq(%w[自分の問い])
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
