module Api
  module V2
    # コンディションログ（1日1回・upsert）。Pro 限定機能。
    class ConditionLogsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :require_pro_entitlement!

      # GET /api/v2/condition_logs/by_date?date=YYYY-MM-DD
      def by_date
        log = current_api_v1_user.condition_logs.find_by(logged_on: params[:date])
        return render json: nil, status: :ok if log.nil?

        render json: log, serializer: ::V2::ConditionLogSerializer, status: :ok
      end

      # POST /api/v2/condition_logs/upsert
      def upsert
        log = current_api_v1_user.condition_logs.find_or_initialize_by(logged_on: condition_log_params[:logged_on])
        if log.update(condition_log_params)
          render json: log, serializer: ::V2::ConditionLogSerializer, status: :ok
        else
          render json: { errors: log.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def require_pro_entitlement!
        return if current_api_v1_user.has_entitlement?('detailed_condition_log')

        render json: { error: 'コンディション記録は Pro プラン限定です' }, status: :forbidden
      end

      def condition_log_params
        params.require(:condition_log).permit(
          :logged_on, :fatigue_level, :physical_level, :sleep_hours, :mood, :memo,
          injuries: %i[part memo]
        )
      end
    end
  end
end
