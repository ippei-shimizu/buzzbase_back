require 'rails_helper'

RSpec.describe Insights::WeeklyMenuVolumeAggregator, type: :service do
  let(:user) { create(:user) }
  let(:monday) { Time.find_zone('Asia/Tokyo').today.beginning_of_week }

  it '週ごとに amount を合計する' do
    menu = create(:practice_menu, user:, unit: 'count')
    create(:practice_log, user:, practice_menu: menu, logged_on: monday, amount: 100)
    create(:practice_log, user:, practice_menu: menu, logged_on: monday + 1, amount: 50)
    result = described_class.new(user:, menu:, since: monday - 7).call
    expect(result[monday]).to eq(150.0)
  end

  it 'weight_reps は amount*weight を合計する' do
    menu = create(:practice_menu, user:, unit: 'weight_reps')
    create(:practice_log, user:, practice_menu: menu, logged_on: monday, amount: 10, weight: 60)
    result = described_class.new(user:, menu:, since: monday - 7).call
    expect(result[monday]).to eq(600.0)
  end
end
