module Stats
  # 打席結果の表示テキスト (例: "中安", "三ゴロ", "左本") をサーバー側で生成する。
  #
  # 旧仕様では mobile/constants/battingData.ts の getResultText でフロント生成していたが、
  # v2 では plate_result_id と hit_direction_id（場合により out_type/hit_type）を組み合わせて
  # サーバー側で一貫した文字列を生成・保存する。
  class BattingResultTextGenerator
    # mobile/constants/battingData.ts:81-98 の resultShortForms と完全一致させる
    SHORT_FORMS = {
      'ゴロ' => 'ゴ',
      'フライ' => '飛',
      'ファールフライ' => '邪飛',
      'ライナー' => '直',
      'エラー' => '失',
      'フィルダースチョイス' => '野選',
      'ヒット' => '安',
      '二塁打' => '二',
      '三塁打' => '三',
      '本塁打' => '本',
      '犠打' => '犠打',
      '犠飛' => '犠飛',
      '振り逃げ' => '振逃',
      '打撃妨害' => '打妨',
      '走塁妨害' => '走妨',
      '併殺打' => '併'
    }.freeze

    # 打席結果テキストを生成する。
    #
    # @param plate_appearance [PlateAppearance] 対象の打席
    # @return [String] 例: "中安"、"三ゴロ"、"左本"。打席方向が無い結果（三振/四球など）は短縮形のみ
    def self.generate(plate_appearance)
      direction_label = plate_appearance.hit_direction&.name.to_s
      result_label = plate_appearance.plate_result&.name.to_s
      short_form = SHORT_FORMS[result_label] || result_label
      "#{direction_label}#{short_form}"
    end
  end
end
