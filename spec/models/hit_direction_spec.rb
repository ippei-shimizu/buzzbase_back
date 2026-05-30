require 'rails_helper'

RSpec.describe HitDirection, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:plate_appearances).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    subject { create(:hit_direction) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:display_order) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
  end

  describe 'seed data' do
    it '内野6方向 + 外野7方向の合計13方向が投入されている' do
      expect(HitDirection.count).to be >= 13
    end

    it '既存IDの意味が維持されている（mobile/constants/battingData.ts と完全一致）' do
      expect(HitDirection.find(1).name).to eq('投')
      expect(HitDirection.find(2).name).to eq('捕')
      expect(HitDirection.find(3).name).to eq('一')
      expect(HitDirection.find(4).name).to eq('二')
      expect(HitDirection.find(5).name).to eq('三')
      expect(HitDirection.find(6).name).to eq('遊')
      expect(HitDirection.find(7).name).to eq('左線')
      expect(HitDirection.find(8).name).to eq('左')
      expect(HitDirection.find(9).name).to eq('左中')
      expect(HitDirection.find(10).name).to eq('中')
      expect(HitDirection.find(11).name).to eq('右中')
      expect(HitDirection.find(12).name).to eq('右')
      expect(HitDirection.find(13).name).to eq('右線')
    end

    it '内野ゾーンは depth: null の単一polygonを持つ' do
      polygon = HitDirection.find(1).zone_polygon
      expect(polygon).to be_a(Hash)
      expect(polygon['depth']).to be_nil
      expect(polygon['polygon']).to be_an(Array)
      expect(polygon['polygon'].size).to eq(4)
      expect(polygon['polygon'].first).to include('x', 'y')
    end

    it '外野ゾーンは depth_id 別の3つのpolygonを持つ' do
      zones = HitDirection.find(10).zone_polygon
      expect(zones).to be_an(Array)
      expect(zones.size).to eq(3)
      expect(zones.map { |z| z['depth_id'] }).to contain_exactly(1, 2, 3)
      zones.each do |z|
        expect(z['polygon']).to be_an(Array)
        expect(z['polygon'].size).to eq(4)
      end
    end
  end
end
