module V2
  # 打席結果(PlateAppearance)のv2シリアライザー
  #
  # v1ではフロントエンドが試合ごとに個別APIで打席結果を取得していた（N+1 HTTPリクエスト）。
  # v2ではGameResultSerializer経由でhas_manyとして一括返却する。
  # issue #331 で新カラム群（打席状況・詳細データ・打球座標等）を露出するように拡張。
  class PlateAppearanceSerializer < ActiveModel::Serializer
    attributes :id, :game_result_id, :user_id,
               :batter_box_number, :batting_result,
               :plate_result_id, :hit_direction_id, :batting_position_id,
               :out_type, :hit_type,
               :hit_location_x, :hit_location_y,
               :rbi, :run_scored, :stolen_bases, :caught_stealing,
               :final_balls, :final_strikes, :final_outs,
               :first_pitch_swing, :runners_state, :inning,
               :self_analysis_memo, :opponent_memo,
               :is_new_format, :has_detail_data,
               :created_at, :updated_at

    has_one :contact_quality, serializer: V2::ContactQualitySerializer
    has_one :timing, serializer: V2::TimingSerializer
    has_one :pitch_type, serializer: V2::PitchTypeSerializer
    has_one :hit_depth, serializer: V2::HitDepthSerializer
    has_one :pitcher, serializer: V2::PitcherSerializer
    has_one :appearance_situation, serializer: V2::AppearanceSituationSerializer

    # mobile 側で「詳細未入力」バッジを出すための boolean。
    # 任意の詳細データ系カラム（マスタID・カウント・状況・メモ）のいずれかに値があれば true。
    # JSON のキー名としてフロントが `has_detail_data` を参照する想定なので Naming/PredicateName を許容する。
    def has_detail_data # rubocop:disable Naming/PredicateName
      detail_attributes.any? { |attr| object.public_send(attr).present? }
    end

    private

    def detail_attributes
      %i[contact_quality_id timing_id pitch_type_id hit_depth_id
         final_balls final_strikes final_outs first_pitch_swing
         runners_state inning self_analysis_memo opponent_memo
         pitcher_id appearance_situation_id]
    end
  end
end
