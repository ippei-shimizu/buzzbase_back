require 'rails_helper'

RSpec.describe InsightCombination, type: :model do
  let(:user) { create(:user) }

  it '不正な input_type は無効' do
    expect(build(:insight_combination, user:, input_type: 'bogus')).not_to be_valid
  end

  it '不正な metric は無効' do
    expect(build(:insight_combination, user:, metric: 'bogus')).not_to be_valid
  end

  it 'practice_menu 入力はメニュー必須' do
    combo = build(:insight_combination, user:, input_type: 'practice_menu', practice_menu: nil)
    expect(combo).not_to be_valid
  end

  it '他ユーザーのメニューは入力に指定できない（IDOR防止）' do
    others_menu = create(:practice_menu, user: create(:user))
    combo = build(:insight_combination, user:, input_type: 'practice_menu', practice_menu: others_menu, metric: 'ops')
    expect(combo).not_to be_valid
    expect(combo.errors[:practice_menu_id]).to be_present
  end

  it '自分のメニュー×指標は有効' do
    menu = create(:practice_menu, user:)
    combo = build(:insight_combination, user:, input_type: 'practice_menu', practice_menu: menu, metric: 'ops')
    expect(combo).to be_valid
  end
end
