require 'rails_helper'

RSpec.describe BaseballNote, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe '#extract_and_truncate_memo' do
    let(:user) { create(:user) }

    it 'memoがnilの場合は空文字を返す' do
      note = create(:baseball_note, user:, memo: nil)
      expect(note.extract_and_truncate_memo).to eq('')
    end

    it 'memoが空文字の場合は空文字を返す' do
      note = create(:baseball_note, user:, memo: '')
      expect(note.extract_and_truncate_memo).to eq('')
    end

    it 'memoからテキストを抽出して返す' do
      memo_json = [{ 'children' => [{ 'text' => 'テストメモ' }] }].to_json
      note = create(:baseball_note, user:, memo: memo_json)
      expect(note.extract_and_truncate_memo).to eq('テストメモ')
    end

    it '120文字を超えるテキストは切り詰める' do
      long_text = 'あ' * 200
      memo_json = [{ 'children' => [{ 'text' => long_text }] }].to_json
      note = create(:baseball_note, user:, memo: memo_json)
      expect(note.extract_and_truncate_memo.length).to be <= 120
    end
  end
end
