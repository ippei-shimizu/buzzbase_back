module Api
  module V2
    # 日次の練習セッション（1日の振り返り）。
    # 日付ごとに複数メニューの量ログとコンディションを束ねて作成・取得・削除する。
    # 量記録・閲覧は無料でも全期間・全件可。コンディション部分のみ Pro 限定。
    class PracticeSessionsController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!

      def index
        sessions = current_api_v1_user.practice_sessions
                                      .includes(:practice_logs, :improvement_themes)
                                      .ordered
        sessions = sessions.where(logged_on: params[:from]..) if params[:from].present?
        sessions = sessions.where(logged_on: ..params[:to]) if params[:to].present?
        if params[:improvement_theme_id].present?
          sessions = sessions.joins(:practice_session_theme_links)
                             .where(practice_session_theme_links: { improvement_theme_id: params[:improvement_theme_id] })
        end
        render json: sessions, each_serializer: ::V2::PracticeSessionSerializer, status: :ok,
               condition_logs_by_date: condition_logs_by_date(sessions.map(&:logged_on))
      end

      def show
        session = current_api_v1_user.practice_sessions
                                     .includes(:practice_logs, :improvement_themes)
                                     .find(params[:id])
        render json: session, serializer: ::V2::PracticeSessionSerializer, status: :ok
      end

      # GET /api/v2/practice_sessions/by_date?date=YYYY-MM-DD
      def by_date
        session = current_api_v1_user.practice_sessions
                                     .includes(:practice_logs, :improvement_themes)
                                     .find_by(logged_on: params[:date])
        return render json: nil, status: :ok if session.nil?

        render json: session, serializer: ::V2::PracticeSessionSerializer, status: :ok
      end

      def create
        session = PracticeSessions::Upsert.new(
          user: current_api_v1_user,
          logged_on: session_params[:logged_on],
          memo: session_params[:memo],
          improvement_theme_ids: session_params[:improvement_theme_ids],
          items: session_params[:items]&.map(&:to_h) || [],
          condition: session_params[:condition]&.to_h
        ).call
        render json: session, serializer: ::V2::PracticeSessionSerializer, status: :created
      rescue PracticeSessions::Upsert::NotEntitled
        render json: { error: 'コンディション記録は Pro プラン限定です' }, status: :forbidden
      rescue PracticeSessions::Upsert::ThemeLimitExceeded
        render json: { error: '複数の課題への紐付けは Pro プラン限定です' }, status: :forbidden
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def destroy
        session = current_api_v1_user.practice_sessions.find(params[:id])
        session.destroy
        render json: { message: '削除しました' }, status: :ok
      end

      private

      # セッション一覧のシリアライズで condition_log を都度 find_by しないよう、
      # 対象日付分の condition_logs を logged_on をキーに一括取得する（N+1 防止）。
      def condition_logs_by_date(dates)
        current_api_v1_user.condition_logs.where(logged_on: dates).index_by(&:logged_on)
      end

      def session_params
        params.require(:practice_session).permit(
          :logged_on, :memo,
          improvement_theme_ids: [],
          items: %i[practice_menu_id amount weight memo],
          condition: [:fatigue_level, :physical_level, :sleep_hours, :mood, :memo, { injuries: %i[part memo] }]
        )
      end
    end
  end
end
