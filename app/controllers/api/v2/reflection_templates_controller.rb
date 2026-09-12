module Api
  module V2
    # 振り返りテンプレ（問いかけ）。運営プリセットは全員が利用でき、ユーザー自作は
    # 無料1つまで / Pro 無制限。編集は原本を更新せず新バージョンを作る（過去ノートの整合性を保つ）。
    # プリセットの編集は共有プリセットを変えず、ユーザー専用コピーを作る。
    class ReflectionTemplatesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_template, only: %i[destroy]

      def index
        templates = ReflectionTemplate.available_for(current_api_v1_user)
        render json: templates, each_serializer: ::V2::ReflectionTemplateSerializer, status: :ok
      end

      def create
        unless current_api_v1_user.can_create_reflection_template?
          return render json: { error: '自作テンプレは無料プランで1つまでです。Pro で無制限に作成できます' },
                        status: :forbidden
        end

        template = current_api_v1_user.reflection_templates.build(template_params)
        if template.save
          render json: template, serializer: ::V2::ReflectionTemplateSerializer, status: :created
        else
          render json: { errors: template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # 編集は原本を更新せず新バージョンを作る。プリセットも対象にするため
      # available_for（プリセット＋自作）から source を引く。
      # プリセットの初編集は自作テンプレの新規作成に等しいため、無料枠を確認する
      # （自分の自作テンプレの再編集は旧版アーカイブ＋新版作成で差し引き0なので対象外）。
      def update
        source = ReflectionTemplate.available_for(current_api_v1_user).find(params[:id])
        if source.user_id.nil? && !current_api_v1_user.can_create_reflection_template?
          return render json: { error: '自作テンプレは無料プランで1つまでです。Pro で無制限に作成できます' },
                        status: :forbidden
        end

        new_version = source.create_edited_version(user: current_api_v1_user, params: template_params)
        if new_version.persisted?
          render json: new_version, serializer: ::V2::ReflectionTemplateSerializer, status: :ok
        else
          render json: { errors: new_version.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # ノートで使用中のテンプレは参照整合性のため削除できない。
      def destroy
        if BaseballNote.exists?(reflection_template_id: @template.id)
          return render json: { error: 'このテンプレは野球ノートで使用されているため削除できません' },
                        status: :unprocessable_entity
        end

        @template.destroy
        render json: { message: '削除しました' }, status: :ok
      end

      private

      # プリセット（user_id nil）は対象外。削除は自分の自作テンプレのみ。
      def load_template
        @template = current_api_v1_user.reflection_templates.find(params[:id])
      end

      def template_params
        params.require(:reflection_template).permit(:title, :is_default, :sort_order, questions: [])
      end
    end
  end
end
