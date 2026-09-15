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

    # ランニング本塁打（走本塁打）はスコアブック表記に合わせて「走本」で表示する。
    # plate_result は本塁打のままなので SHORT_FORMS には載せず、ここで差し替える。
    # mobile の resultShortForms に対応表は無いが、そちらを使う getResultText は
    # 走本塁打の選択肢を持たない v1 打撃入力専用で、v2 はサーバーが返す
    # batting_result をそのまま表示するため不一致は起きない。
    INSIDE_THE_PARK_HOME_RUN_SHORT_FORM = '走本'.freeze

    # 打席結果テキストを生成する。
    #
    # @param plate_appearance [PlateAppearance] 対象の打席
    # @return [String] 例: "中安"、"三ゴロ"、"左本"、"左走本"。打席方向が無い結果（三振/四球など）は短縮形のみ
    def self.generate(plate_appearance)
      direction_label = ::Stats::HitDirectionAggregator::DIRECTION_LABELS[plate_appearance.hit_direction_id].to_s
      "#{direction_label}#{short_form_for(plate_appearance)}"
    end

    def self.short_form_for(plate_appearance)
      return INSIDE_THE_PARK_HOME_RUN_SHORT_FORM if plate_appearance.home_run_type_inside_the_park?

      result_label = plate_appearance.plate_result&.name.to_s
      SHORT_FORMS[result_label] || result_label
    end
    private_class_method :short_form_for
  end
end
