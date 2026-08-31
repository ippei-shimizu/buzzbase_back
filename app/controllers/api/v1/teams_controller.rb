module Api
  module V1
    class TeamsController < ApplicationController
      before_action :authenticate_api_v1_user!, only: %i[create update]
      before_action :set_team, only: %i[update team_name]
      before_action :set_team_by_user, only: %i[my_team]

      # サジェスト用途では十分な件数で、全件シリアライズによるレスポンス遅延を防ぐ。
      DEFAULT_LIMIT = 50
      MAX_LIMIT = 100

      def index
        if params[:q].present? || params[:limit].present?
          teams = Team.order(:name, :id)
          teams = teams.search_by_name(search_query) if search_query.present?
          render json: teams.limit(limit_param)
        else
          # パラメータ無しの全件返却は、配信済みクライアント（旧 mobile アプリの
          # チーム名解決・サジェスト）との互換のために当面残す。teams は単調増加する
          # マスタでレスポンスが肥大し続けるため、クライアントの q / limit 移行が
          # 浸透したらこの分岐を削除して常に limit を適用する。
          render json: Team.all
        end
      end

      def create
        team = Team.find_or_initialize_by(team_params)
        if team.persisted? || team.save
          render json: team, status: :created
        else
          render json: team.errors, status: :unprocessable_entity
        end
      end

      def update
        if @team.update(team_params)
          render json: @team, status: :ok
        else
          render json: @team.errors, status: :unprocessable_entity
        end
      end

      def team_name
        if @team
          render json: { name: @team.name }
        else
          render json: { error: 'チームが見つかりません。' }, status: :not_found
        end
      end

      def my_team
        if @team
          category_name = @team.category&.name
          prefecture_name = @team.prefecture&.name

          render json: {
            name: @team.name,
            category_name:,
            prefecture_name:
          }
        else
          render json: { message: 'チームが見つかりません。' }, status: :ok
        end
      end

      private

      # 未認証で叩けるエンドポイントのため、配列やハッシュを渡されても 500 にせず無視する。
      def search_query
        params[:q].is_a?(String) ? params[:q] : nil
      end

      def limit_param
        limit = Integer(params[:limit].to_s, exception: false).to_i
        return DEFAULT_LIMIT unless limit.positive?

        [limit, MAX_LIMIT].min
      end

      def set_team
        @team = Team.find(params[:id])
      end

      def set_team_by_user
        user = User.find_by(user_id: params[:id])
        if user.nil?
          render json: { error: 'ユーザーが見つかりません。' }, status: :not_found
          return
        end

        @team = Team.find_by(id: user.team_id)
      end

      def team_params
        params.require(:team).permit(:name, :category_id, :prefecture_id)
      end
    end
  end
end
