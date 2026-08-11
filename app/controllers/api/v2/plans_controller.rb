module Api
  module V2
    # 予定（schedules）を日付軸で展開して返す読み取り専用エンドポイント。
    # by_date は「今日のやること」、calendar はカレンダー俯瞰に対応する。
    # 繰り返し（曜日）と単発（planned_on）を同じ日付に集約するのが責務。
    class PlansController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      # 無料ユーザーのカレンダー俯瞰は「直近月中心」に閲覧範囲を絞る(前後3ヶ月)。
      FREE_CALENDAR_WINDOW_MONTHS = 3

      def by_date
        date = parse_date(params[:date])
        return render json: { error: 'date が不正です' }, status: :unprocessable_entity if date.nil?

        render json: plans_on(date),
               each_serializer: ::V2::PlanSerializer,
               done_menu_ids: done_menu_ids_by_schedule_on(date),
               status: :ok
      end

      def calendar
        from = parse_date(params[:from])
        to = parse_date(params[:to])
        return render json: { error: 'from / to が不正です' }, status: :unprocessable_entity if from.nil? || to.nil? || to < from

        unless current_api_v1_user.has_entitlement?('schedule_calendar_full_history')
          today = Time.find_zone('Asia/Tokyo').today
          from = [from, today - FREE_CALENDAR_WINDOW_MONTHS.months].max
          to = [to, today + FREE_CALENDAR_WINDOW_MONTHS.months].min
        end

        entries = (from..to).flat_map { |date| plans_on(date).map { |schedule| calendar_entry(schedule, date) } }
        render json: { entries: }, status: :ok
      end

      private

      # @param schedule [Schedule]
      # @param date [Date] 繰り返し予定を展開した対象日
      # @return [Hash] カレンダー1件分のレスポンス
      def calendar_entry(schedule, date)
        {
          date: date.iso8601,
          event_type: schedule.event_type,
          title: schedule.display_title,
          schedule_id: schedule.id,
          # 「日」表示のタイムラインで時刻軸に配置するため、time 型を保存 TZ に依存しない
          # "HH:MM" 文字列で返す。終日予定は nil。
          scheduled_time: schedule.scheduled_time&.strftime('%H:%M'),
          end_time: schedule.end_time&.strftime('%H:%M')
        }
      end

      def parse_date(value)
        Date.iso8601(value.to_s)
      rescue ArgumentError
        nil
      end

      # ユーザーの active な予定を一度だけ読み込み、日付ごとの展開で再利用する。
      def active_schedules
        @active_schedules ||= current_api_v1_user.schedules.active.includes(
          :game_result,
          { menu_set: { menu_set_items: :practice_menu } },
          { schedule_menus: :practice_menu }
        ).to_a
      end

      # 指定日に該当する予定（繰り返し ∪ 単発）を時刻順（未設定は末尾）で返す。
      # 時刻の time 型は保存タイムゾーンで比較が揺れるため、表示と同じ "HH:MM" 文字列で並べる。
      def plans_on(date)
        weekday = date.wday.zero? ? 7 : date.wday
        active_schedules
          .select { |schedule| (schedule.recurring? && schedule.day_numbers.include?(weekday)) || schedule.planned_on == date }
          .sort_by { |schedule| schedule.scheduled_time&.strftime('%H:%M') || '99:99' }
      end

      # 予定（schedule）単位で「済」を判定するため、当日ログを schedule_id ごとの
      # practice_menu_id 集合に畳み込む。schedule_id を持たないログ（フル記録・素振り等）は
      # どの予定にも紐づかないため除外する。
      # @return [Hash{Integer => Set<Integer>}]
      def done_menu_ids_by_schedule_on(date)
        current_api_v1_user.practice_logs
                           .where(logged_on: date)
                           .where.not(schedule_id: nil)
                           .where.not(practice_menu_id: nil)
                           .pluck(:schedule_id, :practice_menu_id)
                           .each_with_object(Hash.new { |hash, key| hash[key] = Set.new }) do |(schedule_id, practice_menu_id), acc|
          acc[schedule_id] << practice_menu_id
        end
      end
    end
  end
end
