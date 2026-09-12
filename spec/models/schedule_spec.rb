require 'rails_helper'

RSpec.describe Schedule, type: :model do
  let(:user) { create(:user) }

  describe 'メモの長さ' do
    it '上限を超えるメモは保存できない' do
      schedule = build(:schedule, user:, note: 'あ' * (described_class::NOTE_MAX_LENGTH + 1))

      expect(schedule).not_to be_valid
      expect(schedule.errors[:base]).to include("メモは#{described_class::NOTE_MAX_LENGTH}文字以内で入力してください")
    end

    # 上限を後から追加したため、既存の超過データがメモ以外の編集まで巻き込んで修復不能にならないようにする。
    it '既に超過しているメモを触らない更新は通す' do
      schedule = build(:schedule, user:, note: 'あ' * (described_class::NOTE_MAX_LENGTH + 1))
      schedule.save!(validate: false)

      expect(schedule.update(title: '編集後のタイトル')).to be(true)
    end

    it '既に超過しているメモをさらに超過した内容へ変えるのは弾く' do
      schedule = build(:schedule, user:, note: 'あ' * (described_class::NOTE_MAX_LENGTH + 1))
      schedule.save!(validate: false)

      expect(schedule.update(note: 'い' * (described_class::NOTE_MAX_LENGTH + 1))).to be(false)
    end
  end

  describe '終了時刻' do
    it '開始時刻より後なら有効' do
      expect(build(:schedule, user:, scheduled_time: '09:00', end_time: '12:30')).to be_valid
    end

    it '開始時刻が無いと指定できない' do
      schedule = build(:schedule, user:, scheduled_time: nil, end_time: '12:30')

      expect(schedule).not_to be_valid
      expect(schedule.errors[:base]).to include('終了時刻は開始時刻とセットで指定してください')
    end

    it '開始時刻以前は指定できない' do
      schedule = build(:schedule, user:, scheduled_time: '09:00', end_time: '09:00')

      expect(schedule).not_to be_valid
      expect(schedule.errors[:base]).to include('終了時刻は開始時刻より後にしてください')
    end

    it '未設定なら有効' do
      expect(build(:schedule, user:, scheduled_time: '09:00', end_time: nil)).to be_valid
    end
  end
end
