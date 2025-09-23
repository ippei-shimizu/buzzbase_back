module Admin
  module Analytics
    class UsersService
      def initialize(params)
        @page = params[:page]&.to_i || 1
        @per_page = params[:per_page]&.to_i || 20
        @search_term = params[:search]
      end

      def call
        {
          users: Admin::Analytics::UsersSerializer.serialize(paginated_users),
          pagination: pagination_info,
          total_count: filtered_users.count
        }
      end

      private

      def filtered_users
        @filtered_users ||= begin
          users = User.all
          users = users.where('name ILIKE ? OR email ILIKE ?', "%#{@search_term}%", "%#{@search_term}%") if @search_term.present?
          users.order(:created_at)
        end
      end

      def paginated_users
        @paginated_users ||= filtered_users.limit(@per_page).offset((@page - 1) * @per_page)
      end

      def pagination_info
        total_count = filtered_users.count
        total_pages = (total_count.to_f / @per_page).ceil

        {
          current_page: @page,
          per_page: @per_page,
          total_pages:,
          total_count:,
          has_next: @page < total_pages,
          has_prev: @page > 1
        }
      end
    end
  end
end
