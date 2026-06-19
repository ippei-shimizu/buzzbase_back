module Api
  module V2
    # 打席記録 v2 CRUD（1打席ずつリアルタイム保存）
    #
    # - `is_new_format = true` を強制セットすることで「新仕様試合」とマークする
    # - `batting_result` 表示テキストをサーバー側で自動生成
    # - `batting_average` の再集計は PlateAppearance の after_commit /
    #   after_destroy_commit に委ねる（controller 経由でも runner / 一括投入でも
    #   同じ起動経路に統一する）
    # - v1 API は無修正、後方互換を保つ
    class PlateAppearancesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_plate_appearance, only: %i[update destroy]

      def create
        # game_result_id を current_api_v1_user 所有のものに限定し、IDOR を防ぐ。
        game_result = current_api_v1_user.game_results.find(plate_appearance_params[:game_result_id])
        return if pitcher_id_invalid?(plate_appearance_params[:pitcher_id])

        plate_appearance = game_result.plate_appearances.build(plate_appearance_params.except(:game_result_id))
        plate_appearance.user = current_api_v1_user
        plate_appearance.is_new_format = true
        plate_appearance.batting_result = ::Stats::BattingResultTextGenerator.generate(plate_appearance)

        if plate_appearance.save
          render json: plate_appearance, serializer: ::V2::PlateAppearanceSerializer, status: :created
        else
          render json: { errors: plate_appearance.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        # 更新時は所属 game_result の付け替えを許さない（IDOR 防止）。
        return if pitcher_id_invalid?(plate_appearance_params[:pitcher_id])

        @plate_appearance.assign_attributes(plate_appearance_params.except(:game_result_id))
        @plate_appearance.is_new_format = true
        @plate_appearance.batting_result = ::Stats::BattingResultTextGenerator.generate(@plate_appearance)

        if @plate_appearance.save
          render json: @plate_appearance, serializer: ::V2::PlateAppearanceSerializer
        else
          render json: { errors: @plate_appearance.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @plate_appearance.destroy!
        render json: { message: '打席結果を削除しました' }
      end

      def by_game
        game_result = GameResult.find(params[:game_result_id])
        # render_forbidden_if_private! は非公開アカウントへのアクセスを 403 で render し true を返す。
        # 呼び出し側は戻り値で短絡（early return）して以降の処理をスキップする。
        return if render_forbidden_if_private!(game_result.user)

        plate_appearances = PlateAppearance.where(game_result_id: game_result.id)
                                           .includes(:contact_quality, :timing, :pitch_type,
                                                     :appearance_situation,
                                                     pitcher: %i[arm_angle velocity_zone pitcher_style])
                                           .order(:batter_box_number)
        render json: {
          plate_appearances: ActiveModelSerializers::SerializableResource.new(
            plate_appearances,
            each_serializer: ::V2::PlateAppearanceSerializer
          )
        }
      end

      private

      def load_plate_appearance
        @plate_appearance = current_api_v1_user.plate_appearances.find(params[:id])
      end

      def plate_appearance_params
        params.require(:plate_appearance).permit(
          :game_result_id,
          :batter_box_number,
          :plate_result_id, :hit_direction_id, :batting_position_id,
          :out_type, :hit_type, :swing_type,
          :hit_location_x, :hit_location_y,
          :rbi, :run_scored, :stolen_bases, :caught_stealing,
          :final_balls, :final_strikes, :final_outs,
          :first_pitch_swing, :runners_state, :inning,
          :contact_quality_id, :timing_id, :pitch_type_id,
          :self_analysis_memo, :opponent_memo,
          :pitcher_id, :appearance_situation_id
        )
      end

      # 投手はユーザー固有マスタのため、他ユーザーが作成した pitcher_id を
      # 紐付ける攻撃を防ぐ。指定された pitcher_id が存在するが current user の作成物でない場合、
      # 422 を返して呼び出し側の早期 return を促す。
      def pitcher_id_invalid?(pitcher_id)
        return false if pitcher_id.blank?
        return false if current_api_v1_user.created_pitchers.exists?(id: pitcher_id)

        render json: { errors: ['指定された投手は存在しません'] }, status: :unprocessable_entity
        true
      end
    end
  end
end
