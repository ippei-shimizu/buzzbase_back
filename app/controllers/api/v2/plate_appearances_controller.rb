module Api
  module V2
    # 打席記録 v2 CRUD（1打席ずつリアルタイム保存）
    #
    # - `is_new_format = true` を強制セットすることで「新仕様試合」とマークする
    # - `batting_result` 表示テキストをサーバー側で自動生成
    # - `batting_average` を `Stats::BattingAverageRecalculator` で自動再集計
    # - v1 API は無修正、後方互換を保つ
    class PlateAppearancesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_plate_appearance, only: %i[update destroy]

      def create
        # game_result_id を current_api_v1_user 所有のものに限定し、IDOR を防ぐ。
        game_result = current_api_v1_user.game_results.find(plate_appearance_params[:game_result_id])
        plate_appearance = game_result.plate_appearances.build(plate_appearance_params.except(:game_result_id))
        plate_appearance.user = current_api_v1_user
        plate_appearance.is_new_format = true
        plate_appearance.batting_result = ::Stats::BattingResultTextGenerator.generate(plate_appearance)

        if plate_appearance.save
          recalculate_batting_average(plate_appearance.game_result_id, user_id: current_api_v1_user.id)
          render json: plate_appearance, serializer: ::V2::PlateAppearanceSerializer, status: :created
        else
          render json: { errors: plate_appearance.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        # 更新時は所属 game_result の付け替えを許さない（IDOR 防止）。
        @plate_appearance.assign_attributes(plate_appearance_params.except(:game_result_id))
        @plate_appearance.is_new_format = true
        @plate_appearance.batting_result = ::Stats::BattingResultTextGenerator.generate(@plate_appearance)

        if @plate_appearance.save
          recalculate_batting_average(@plate_appearance.game_result_id, user_id: current_api_v1_user.id)
          render json: @plate_appearance, serializer: ::V2::PlateAppearanceSerializer
        else
          render json: { errors: @plate_appearance.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        game_result_id = @plate_appearance.game_result_id
        # 削除する打席が新仕様だった場合、最後の1件であれば対応する batting_average も
        # 削除する必要がある（孤立レコード防止）。was_new_format を Recalculator に渡して判断させる。
        was_new_format = @plate_appearance.is_new_format
        @plate_appearance.destroy!
        recalculate_batting_average(game_result_id, user_id: current_api_v1_user.id, cleanup_orphan: was_new_format)
        render json: { message: '打席結果を削除しました' }
      end

      def by_game
        game_result = GameResult.find(params[:game_result_id])
        # render_forbidden_if_private! は非公開アカウントへのアクセスを 403 で render し true を返す。
        # 呼び出し側は戻り値で短絡（early return）して以降の処理をスキップする。
        return if render_forbidden_if_private!(game_result.user)

        plate_appearances = PlateAppearance.where(game_result_id: game_result.id)
                                           .includes(:contact_quality, :timing, :pitch_type, :hit_depth)
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
          :out_type, :hit_type,
          :hit_location_x, :hit_location_y,
          :rbi, :run_scored, :stolen_bases, :caught_stealing,
          :final_balls, :final_strikes, :final_outs,
          :first_pitch_swing, :runners_state, :inning,
          :contact_quality_id, :timing_id, :pitch_type_id, :hit_depth_id,
          :self_analysis_memo, :opponent_memo
        )
      end

      def recalculate_batting_average(game_result_id, user_id:, cleanup_orphan: false)
        ::Stats::BattingAverageRecalculator.new(game_result_id:, user_id:, cleanup_orphan:).call
      end
    end
  end
end
