require 'rails_helper'

RSpec.describe Group, type: :model do
  describe 'アイコンアップロード（store の after_commit 化）' do
    # CI に ImageMagick が無くても実行できるよう、リサイズ処理はスキップして
    # cache → store の流れ（after_commit で store されるか）だけを検証する。
    around do |example|
      GroupIconUploader.enable_processing = false
      example.run
    ensure
      GroupIconUploader.enable_processing = true
    end

    let(:group) { create(:group) }
    let(:icon_file) { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/avatar.png'), 'image/png') }

    it 'update の COMMIT 後に store されファイルが保存される' do
      group.update!(icon: icon_file)

      expect(group.reload.icon.file.exists?).to be true
      expect(group.reload[:icon]).to eq('avatar.png')
    end

    # store が after_save に戻ってしまう回帰（skip_callback の失効）を検知するため、
    # トランザクション内では未 store であることまで確認する。
    it 'COMMIT 前は store されていない' do
      described_class.transaction do
        group.update!(icon: icon_file)

        expect(described_class.find(group.id).icon.file&.exists?).to be_falsey
      end

      expect(described_class.find(group.id).icon.file.exists?).to be true
    end

    it 'store に失敗した場合は識別子を元に戻して例外を伝播する' do
      # store! はアイコンの有無に関わらず保存時に呼ばれるため、グループ作成後にスタブする。
      group
      allow_any_instance_of(GroupIconUploader).to receive(:store!).and_raise('S3 unreachable') # rubocop:disable RSpec/AnyInstance

      expect { group.update!(icon: icon_file) }.to raise_error('S3 unreachable')
      expect(group.reload[:icon]).to be_nil
    end
  end
end
