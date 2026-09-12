require 'rails_helper'

RSpec.describe MediaAttachments::VideoMetadataFetcher do
  subject(:metadata) { described_class.new(r2_key: 'user/1/video.mp4').call }

  context 'moov が先頭側にあるとき（iOS の faststart 配置）' do
    before { stub_r2_video_object(build_mp4(duration_seconds: 42, width: 1920, height: 1080)) }

    it '実ファイルの再生時間と解像度を返す' do
      expect(metadata).to have_attributes(duration_seconds: 42, width: 1920, height: 1080)
    end
  end

  context 'moov が mdat の後ろにあるとき（Android の典型配置）' do
    before { stub_r2_video_object(build_mp4(duration_seconds: 12, width: 640, height: 480, moov_last: true)) }

    it 'mdat を読み飛ばして解析できる' do
      expect(metadata).to have_attributes(duration_seconds: 12, width: 640, height: 480)
    end
  end

  context '再生時間に端数があるとき' do
    before { stub_r2_video_object(build_mp4(duration_seconds: 30.4, width: 640, height: 480)) }

    it '切り上げて返す（上限ぴったりに丸めて無料枠を通さない）' do
      expect(metadata.duration_seconds).to eq 31
    end
  end

  context '縦持ち撮影で90度回転のマトリクスが入っているとき' do
    before { stub_r2_video_object(build_mp4(duration_seconds: 10, width: 1920, height: 1080, rotated: true)) }

    it '表示サイズに合わせて幅と高さを入れ替える' do
      expect(metadata).to have_attributes(width: 1080, height: 1920)
    end
  end

  context '音声トラックを含むとき' do
    before { stub_r2_video_object(build_mp4(duration_seconds: 10, width: 1280, height: 720, audio_track: true)) }

    it '0x0 の音声トラックではなく映像トラックの解像度を返す' do
      expect(metadata).to have_attributes(width: 1280, height: 720)
    end
  end

  context '中身が空のボックスが挟まっているとき' do
    before do
      stub_r2_video_object(build_mp4(duration_seconds: 10, width: 640, height: 480, empty_box: true))
    end

    it '読み飛ばして解析を続ける' do
      expect(metadata).to have_attributes(duration_seconds: 10, width: 640, height: 480)
    end
  end

  context 'MP4 として解析できないファイルのとき' do
    before { stub_r2_video_object('this is not a video'.b * 8) }

    it 'nil を返す' do
      expect(metadata).to be_nil
    end
  end

  context 'moov ボックスが存在しないとき' do
    before { stub_r2_video_object(build_mp4(duration_seconds: 10, width: 640, height: 480).sub('moov', 'free')) }

    it 'nil を返す' do
      expect(metadata).to be_nil
    end
  end

  context 'R2 にオブジェクトが無いとき' do
    before do
      allow(MediaAttachments::PresignedUrlService.client).to receive(:get_object)
        .and_raise(Aws::S3::Errors::NoSuchKey.new(nil, 'no such key'))
    end

    it 'nil を返す' do
      expect(metadata).to be_nil
    end
  end
end
