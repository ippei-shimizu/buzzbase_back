require 'rails_helper'

RSpec.describe PracticeMenu do
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
