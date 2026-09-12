module Api
  module V2
    module Schedules
      # 週の練習プラン（単発予定のみ）を翌週へ一括コピーする。Pro限定機能。
      class WeekCopiesController < Api::V2::ApplicationController
        before_action :authenticate_api_v1_user!

        # POST /api/v2/schedules/week_copy
        # @param week_start [String] コピー元の週の開始日（YYYY-MM-DD）
        def create
          unless current_api_v1_user.has_entitlement?('schedule_copy_next_week')
            return render json: { error: '来週にコピーは Pro プラン限定です' }, status: :forbidden
          end

          week_start = parse_date(params[:week_start])
          return render json: { error: 'week_start が不正です' }, status: :unprocessable_entity if week_start.nil?

          copied = ActiveRecord::Base.transaction do
            source_schedules(week_start).filter_map { |schedule| copy_to_next_week(schedule) }
          end
          render json: copied, each_serializer: ::V2::ScheduleSerializer, status: :created
        end

        private

        def parse_date(value)
          Date.parse(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end

        def source_schedules(week_start)
          current_api_v1_user.schedules.active.single.includes(:schedule_menus)
                             .where(planned_on: week_start..(week_start + 6.days))
        end

        def copy_to_next_week(schedule)
          target_date = schedule.planned_on + 7.days
          # 連続実行での二重コピーを避け、コピー先に同一内容の予定が既にあればスキップする。
          return nil if already_copied?(schedule, target_date)

          new_schedule = current_api_v1_user.schedules.create!(
            title: schedule.title,
            event_type: schedule.event_type,
            scheduled_time: schedule.scheduled_time,
            end_time: schedule.end_time,
            planned_on: target_date,
            note: schedule.note,
            notification_enabled: schedule.notification_enabled,
            notification_message: schedule.notification_message,
            menu_set_id: schedule.menu_set_id
          )
          return new_schedule if schedule.menu_set_id

          schedule.schedule_menus.each do |menu|
            new_schedule.schedule_menus.create!(
              practice_menu_id: menu.practice_menu_id,
              target_value: menu.target_value,
              sort_order: menu.sort_order
            )
          end
          new_schedule
        end

        # 判定キーに note / end_time は含めない。後から追加したカラムを条件に足すと、
        # 追加前にコピー済みの週が「未コピー」と判定されて重複生成されるため。
        def already_copied?(schedule, target_date)
          current_api_v1_user.schedules.active.single.exists?(
            planned_on: target_date,
            title: schedule.title,
            event_type: schedule.event_type,
            scheduled_time: schedule.scheduled_time,
            menu_set_id: schedule.menu_set_id
          )
        end
      end
    end
  end
end
