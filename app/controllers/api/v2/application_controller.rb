module Api
  module V2
    # v2 API 共通基盤。
    # 認証 (`authenticate_api_v1_user!`) は各 controller のポリシーが異なるため、
    # 基底クラスでは強制せず、`paginated_response` などの共通ヘルパーのみ提供する。
    class ApplicationController < ::ApplicationController
      private

      # kaminari でページネーションされた scope を共通 JSON 形式で返却する。
      #
      # @param scope [ActiveRecord::Relation] kaminari でページング済みのスコープ
      # @param serializer [Class<ActiveModel::Serializer>] 各レコードのシリアライザ
      # @return [Hash] `{ data: [...], pagination: { current_page:, per_page:, total_count:, total_pages: } }`
      def paginated_response(scope, serializer)
        {
          data: ActiveModelSerializers::SerializableResource.new(scope, each_serializer: serializer),
          pagination: {
            current_page: scope.current_page,
            per_page: scope.limit_value,
            total_count: scope.total_count,
            total_pages: scope.total_pages
          }
        }
      end

      # 非公開アカウントへのアクセスを 403 で拒否する共通ガード。
      # 表示可能ならそのまま続行する。
      #
      # @param user [User] アクセス対象のユーザー
      # @return [TrueClass, nil] 非公開で render した場合 truthy / 公開で何もしない場合 nil
      #
      # action 内で続けて render したい場合は戻り値で短絡（early return）する:
      #   return if render_forbidden_if_private!(target_user)
      #
      # `before_action` から呼ぶ場合は、render 済みであれば Rails が後続 action を
      # 自動で止めるため明示の `return if` は不要。いずれのケースでも、`render` 後に
      # 追加の `render` を呼ぶと DoubleRenderError になる点に注意。
      def render_forbidden_if_private!(user)
        return if user.profile_visible_to?(current_api_v1_user)

        render json: { error: 'このアカウントは非公開です' }, status: :forbidden
        true
      end
    end
  end
end
