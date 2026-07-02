module Api
  module V2
    # 自主練スケジュール。無料は3つまで（PlanLimits）。
    # 通知のリマインド自体は端末側のローカル通知で行う（サーバーは設定の保管のみ）。
    class SchedulesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_schedule, only: %i[update destroy]

      def index
        schedules = current_api_v1_user.schedules.active
                                       .includes(schedule_menus: :practice_menu)
                                       .order(:scheduled_time)
        render json: schedules, each_serializer: ::V2::ScheduleSerializer, status: :ok
      end

      def create
        return render json: { error: 'Pro プランでスケジュールを無制限に登録できます' }, status: :forbidden unless current_api_v1_user.can_create_schedule?

        schedule = current_api_v1_user.schedules.build(schedule_params)
        assign_menus(schedule)
        if schedule.save
          render json: schedule, serializer: ::V2::ScheduleSerializer, status: :created
        else
          render json: { errors: schedule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        @schedule.assign_attributes(schedule_params)
        assign_menus(@schedule) if params[:schedule].key?(:menus)
        if @schedule.save
          render json: @schedule, serializer: ::V2::ScheduleSerializer, status: :ok
        else
          render json: { errors: @schedule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @schedule.destroy
        render json: { message: '削除しました' }, status: :ok
      end

      private

      def load_schedule
        @schedule = current_api_v1_user.schedules.find(params[:id])
      end

      # カスタム通知文は Pro 限定。無料ユーザーの指定は無視する。
      def schedule_params
        permitted = params.require(:schedule).permit(
          :title, :days_of_week, :scheduled_time, :note, :notification_enabled, :active, :notification_message
        )
        permitted.delete(:notification_message) unless current_api_v1_user.has_entitlement?('custom_notification_messages')
        permitted
      end

      def assign_menus(schedule)
        menus = params.dig(:schedule, :menus) || []
        # 他ユーザーの practice_menu_id を紐付けられないよう、所有メニューに限定する（IDOR 防止）。
        allowed_ids = schedule.user.practice_menus.where(id: menus.pluck(:practice_menu_id)).pluck(:id).to_set
        schedule.schedule_menus.destroy_all if schedule.persisted?
        menus.each_with_index do |menu, index|
          next unless allowed_ids.include?(menu[:practice_menu_id].to_i)

          schedule.schedule_menus.build(
            practice_menu_id: menu[:practice_menu_id],
            target_value: menu[:target_value],
            sort_order: index
          )
        end
      end
    end
  end
end
