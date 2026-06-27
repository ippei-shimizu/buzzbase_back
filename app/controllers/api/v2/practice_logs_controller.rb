module Api
  module V2
    # 練習量記録（量ログ）の作成・取得・削除。
    # 量記録・閲覧は無料でも全期間・全件可（Pro 差別化はメニュー数・コンディション側）。
    class PracticeLogsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        logs = current_api_v1_user.practice_logs.includes(:practice_menu)
        logs = logs.where(logged_on: params[:from]..) if params[:from].present?
        logs = logs.where(logged_on: ..params[:to]) if params[:to].present?
        logs = logs.order(logged_on: :desc, created_at: :desc)
        render json: logs, each_serializer: ::V2::PracticeLogSerializer, status: :ok
      end

      def create
        menu = current_api_v1_user.practice_menus.find(practice_log_params[:practice_menu_id])
        log = current_api_v1_user.practice_logs.build(
          practice_log_params.except(:practice_menu_id).merge(
            practice_menu: menu,
            menu_name: menu.name,
            unit_label: menu.unit_label
          )
        )
        if log.save
          render json: log, serializer: ::V2::PracticeLogSerializer, status: :created
        else
          render json: { errors: log.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        log = current_api_v1_user.practice_logs.find(params[:id])
        log.destroy
        render json: { message: '削除しました' }, status: :ok
      end

      private

      def practice_log_params
        params.require(:practice_log).permit(:practice_menu_id, :logged_on, :amount, :memo)
      end
    end
  end
end
