require 'rails_helper'

RSpec.describe PracticeMenu do
  let(:user) { create(:user) }

  describe '素振りメニューの重複バリデーション' do
    let(:shadow_swing_attributes) do
      { name: described_class::SHADOW_SWING_NAME, category: 'batting', unit: described_class::SHADOW_SWING_UNIT }
    end

    it '同じユーザーに active な素振りメニューがあれば無効になる' do
      create(:practice_menu, user:, **shadow_swing_attributes)

      menu = user.practice_menus.build(shadow_swing_attributes)

      expect(menu).not_to be_valid
      expect(menu.errors[:base]).to include(a_string_matching(described_class::SHADOW_SWING_NAME))
    end

    it '既存の素振りメニューが削除済みなら有効になる' do
      create(:practice_menu, user:, **shadow_swing_attributes, archived: true)

      expect(user.practice_menus.build(shadow_swing_attributes)).to be_valid
    end

    it '他ユーザーの素振りメニューは重複扱いしない' do
      create(:practice_menu, user: create(:user), **shadow_swing_attributes)

      expect(user.practice_menus.build(shadow_swing_attributes)).to be_valid
    end

    it '単位が違えば重複扱いしない' do
      create(:practice_menu, user:, **shadow_swing_attributes)

      expect(user.practice_menus.build(**shadow_swing_attributes, unit: 'minutes')).to be_valid
    end

    it '素振りメニュー自身の更新では自分を重複扱いしない' do
      menu = create(:practice_menu, user:, **shadow_swing_attributes)

      expect(menu.update(unit_label: '回')).to be(true)
    end

    it '既存の素振りメニューと重複する改名は無効になる' do
      create(:practice_menu, user:, **shadow_swing_attributes)
      other = create(:practice_menu, user:, name: 'ティー', category: 'batting', unit: 'count')

      other.name = described_class::SHADOW_SWING_NAME

      expect(other).not_to be_valid
    end
  end

  describe '素振りメニューの部分ユニークインデックス' do
    it 'バリデーションと同じ条件（name / unit / archived）で張られている' do
      index = ActiveRecord::Base.connection.indexes(:practice_menus)
                                .find { |i| i.name == 'index_practice_menus_on_user_id_and_shadow_swing_name' }

      aggregate_failures do
        expect(index.where).to include(described_class::SHADOW_SWING_NAME)
        expect(index.where).to include(described_class::SHADOW_SWING_UNIT)
        expect(index.where).to include('archived = false')
      end
    end
  end
end
