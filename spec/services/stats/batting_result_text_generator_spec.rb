require 'rails_helper'

RSpec.describe Stats::BattingResultTextGenerator, type: :service do
  describe '.generate' do
    # mobile/constants/battingData.ts:100-107 の getResultText と同じ出力になることを担保
    # rubocop:disable Style/HashEachMethods
    {
      [10, 7] => '中安', # 中 + ヒット
      [1, 1] => '投ゴ', # 投 + ゴロ
      [8, 10] => '左本', # 左 + 本塁打
      [13, 8] => '右線二', # 右線 + 二塁打
      [5, 5] => '三失', # 三 + エラー
      [11, 2] => '右中飛', # 右中 + フライ
      [2, 3] => '捕邪飛',     # 捕 + ファールフライ
      [9, 4] => '左中直',     # 左中 + ライナー
      [7, 6] => '左線野選', # 左線 + フィルダースチョイス
      [4, 19] => '二併' # 二 + 併殺打
    }.each do |(direction_id, result_id), expected_text|
      it "hit_direction_id=#{direction_id} + plate_result_id=#{result_id} で #{expected_text} を返す" do
        plate_appearance = build_stubbed(
          :plate_appearance,
          hit_direction_id: direction_id,
          plate_result: PlateResult.find(result_id)
        )
        expect(described_class.generate(plate_appearance)).to eq(expected_text)
      end
    end
    # rubocop:enable Style/HashEachMethods

    context '打球方向なし結果（hit_direction_id が nil）' do
      it '三振は短縮形のみ（hit_direction_id が nil）' do
        plate_appearance = build_stubbed(
          :plate_appearance,
          hit_direction_id: nil,
          plate_result: PlateResult.find(13) # 三振
        )
        expect(described_class.generate(plate_appearance)).to eq('三振')
      end

      it '四球は短縮形のみ' do
        plate_appearance = build_stubbed(
          :plate_appearance,
          hit_direction_id: nil,
          plate_result: PlateResult.find(15) # 四球
        )
        expect(described_class.generate(plate_appearance)).to eq('四球')
      end

      it 'plate_result も nil の場合は空文字' do
        plate_appearance = build_stubbed(:plate_appearance, hit_direction_id: nil, plate_result: nil)
        expect(described_class.generate(plate_appearance)).to eq('')
      end
    end
  end
end
