module Api
  module V2
    # 練習プランの割り当て（繰り返し / 単発）。件数上限なし。
    # 通知のリマインド自体は端末側のローカル通知で行う（サーバーは設定の保管のみ）。
    class SchedulesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_schedule, only: %i[update destroy]

      def index
        schedules = current_api_v1_user.schedules.active
                                       .includes(:game_result, :practice_logs,
                                                 { menu_set: { menu_set_items: :practice_menu } },
                                                 { schedule_menus: :practice_menu })
                                       .order(:scheduled_time)
        render json: schedules, each_serializer: ::V2::ScheduleSerializer, status: :ok
      end

      def create
        schedule = current_api_v1_user.schedules.build(schedule_params)
        assign_menus(schedule)
        if schedule.save
          render json: schedule, serializer: ::V2::ScheduleSerializer, status: :created
        else
          render json: { errors: schedule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        # assign_menus の destroy_all は即時実行されるため、save失敗時に schedule_menus だけ
        # 消えて残らないよう、属性更新・メニュー再構築・保存を1トランザクションに包む。
        ActiveRecord::Base.transaction do
          @schedule.assign_attributes(schedule_params)
          assign_menus(@schedule) if params[:schedule].key?(:menus)
          @schedule.save!
        end
        render json: @schedule, serializer: ::V2::ScheduleSerializer, status: :ok
      rescue ActiveRecord::RecordInvalid
        render json: { errors: @schedule.errors.full_messages }, status: :unprocessable_entity
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
      # menu_set_id は所有セットのみ許可する（IDOR 防止）。
      def schedule_params
        permitted = params.require(:schedule).permit(
          :title, :days_of_week, :planned_on, :scheduled_time, :event_type, :menu_set_id,
          :note, :notification_enabled, :active, :notification_message
        )
        permitted.delete(:notification_message) unless current_api_v1_user.has_entitlement?('custom_notification_messages')
        if permitted[:menu_set_id].present? && !current_api_v1_user.menu_sets.exists?(id: permitted[:menu_set_id])
          permitted.delete(:menu_set_id)
        end
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
