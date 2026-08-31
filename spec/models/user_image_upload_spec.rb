require 'rails_helper'

RSpec.describe User, type: :model do
  describe '画像アップロード（store の after_commit 化）' do
    # CI に ImageMagick が無くても実行できるよう、リサイズ処理はスキップして
    # cache → store の流れ（after_commit で store されるか）だけを検証する。
    around do |example|
      AvatarUploader.enable_processing = false
      example.run
    ensure
      AvatarUploader.enable_processing = true
    end

    let(:user) { create(:user) }
    let(:image_file) { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/avatar.png'), 'image/png') }

    it 'update の COMMIT 後に store されファイルが保存される' do
      user.update!(image: image_file)

      expect(user.reload.image.file).to be_present
      expect(user.image.file.exists?).to be true
    end

    it 'identifier が保存されカラムに反映される' do
      user.update!(image: image_file)

      expect(user.reload[:image]).to eq('avatar.png')
    end

    it 'store に失敗した場合は識別子を元に戻して例外を伝播する' do
      # store! は画像の有無に関わらず保存時に呼ばれるため、ユーザー作成後にスタブする。
      user
      allow_any_instance_of(AvatarUploader).to receive(:store!).and_raise('S3 unreachable') # rubocop:disable RSpec/AnyInstance

      expect { user.update!(image: image_file) }.to raise_error('S3 unreachable')
      expect(user.reload[:image]).to be_nil
    end
  end
end
