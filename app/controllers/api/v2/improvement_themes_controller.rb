module Api
  module V2
    # 課題（テーマ）。選手が一定期間集中的に取り組む上達テーマを管理する。
    # 練習セッション / ノートに緩く紐付き、取組状況を集計する。
    # 無料は取組中（open）が1つまで、Pro は無制限。
    class ImprovementThemesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_theme, only: %i[update destroy]

      def index
        themes = current_api_v1_user.improvement_themes.ordered
        themes = themes.where(status: params[:status]) if params[:status].present?
        render json: themes, each_serializer: ::V2::ImprovementThemeSerializer, status: :ok
      end

      def create
        unless current_api_v1_user.can_create_improvement_theme?
          return render json: { error: '取組中の課題は無料プランで1つまでです。Pro で無制限に設定できます' },
                        status: :forbidden
        end

        theme = current_api_v1_user.improvement_themes.build(theme_params)
        if theme.save
          render json: theme, serializer: ::V2::ImprovementThemeSerializer, status: :created
        else
          render json: { errors: theme.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @theme.update(theme_params)
          render json: @theme, serializer: ::V2::ImprovementThemeSerializer, status: :ok
        else
          render json: { errors: @theme.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @theme.destroy
        render json: { message: '削除しました' }, status: :ok
      end

      private

      def load_theme
        @theme = current_api_v1_user.improvement_themes.find(params[:id])
      end

      def theme_params
        params.require(:improvement_theme).permit(:title, :category, :purpose, :status, :achieved_on, :sort_order)
      end
    end
  end
end
