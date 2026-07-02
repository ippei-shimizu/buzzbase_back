module Api
  module V2
    # 振り返りテンプレ（問いかけ）。運営プリセットは全員が利用でき、ユーザー自作は
    # 無料1つまで / Pro 無制限。プリセットはユーザーからは作成・編集・削除できない。
    class ReflectionTemplatesController < Api::V2::ApplicationController
      before_action :authenticate_api_v1_user!
      before_action :load_template, only: %i[update destroy]

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

      def update
        if @template.update(template_params)
          render json: @template, serializer: ::V2::ReflectionTemplateSerializer, status: :ok
        else
          render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @template.destroy
        render json: { message: '削除しました' }, status: :ok
      end

      private

      # プリセット（user_id nil）は対象外。自分の自作テンプレのみ操作できる。
      def load_template
        @template = current_api_v1_user.reflection_templates.find(params[:id])
      end

      def template_params
        params.require(:reflection_template).permit(:title, :is_default, :sort_order, questions: [])
      end
    end
  end
end
