module Admin
  class UserManagementService
    DEFAULT_PER_PAGE = 20
    MAX_PER_PAGE = 100
    SORTABLE_COLUMNS = %w[created_at last_login_at name game_results_count followers_count].freeze
    # PostgreSQL bigint の最大値。検索語を users.id として扱う前にこの範囲をガードし、
    # 巨大な数値文字列で StatementInvalid（範囲外）になるのを防ぐ。
    BIGINT_MAX = 9_223_372_036_854_775_807

    def initialize(params = {})
      @page = [params[:page].to_i, 1].max
      @per_page = params[:per_page].to_i.between?(1, MAX_PER_PAGE) ? params[:per_page].to_i : DEFAULT_PER_PAGE
      @search = params[:search]
      @sort_by = SORTABLE_COLUMNS.include?(params[:sort_by]) ? params[:sort_by] : 'created_at'
      @sort_order = params[:sort_order] == 'asc' ? 'asc' : 'desc'
      @status = params[:status]
      @date_from = params[:date_from]
      @date_to = params[:date_to]
    end

    def call
      users = base_scope
      users = apply_status_filter(users)
      users = apply_search(users)
      users = apply_date_filter(users)
      total_count = users.count
      users = apply_sort(users)
      users = apply_pagination(users)

      {
        users:,
        pagination: {
          current_page: @page,
          per_page: @per_page,
          total_count:,
          total_pages: (total_count.to_f / @per_page).ceil
        }
      }
    end

    private

    def base_scope
      ::User.includes(:game_results, :batting_averages, :pitching_results, :baseball_notes, :groups, :followers)
    end

    def apply_status_filter(users)
      case @status
      when 'active'
        users.active
      when 'suspended'
        users.suspended
      when 'deleted'
        users.soft_deleted
      else
        users.not_deleted
      end
    end

    def apply_search(users)
      return users if @search.blank?

      search_term = "%#{@search}%"
      # PostHog の distinct_id は users.id（主キー）なので、検索語が数値なら id 完全一致も OR で許す。
      # 数字を含むハンドル名（user_id）も従来どおりヒットさせるため ILIKE の OR は残す。
      if @search.match?(/\A\d+\z/) && @search.to_i <= BIGINT_MAX
        users.where(
          'users.id = :id OR name ILIKE :term OR email ILIKE :term OR user_id ILIKE :term',
          id: @search.to_i, term: search_term
        )
      else
        users.where('name ILIKE :term OR email ILIKE :term OR user_id ILIKE :term', term: search_term)
      end
    end

    def apply_date_filter(users)
      users = users.where('users.created_at >= ?', @date_from.to_date.beginning_of_day) if @date_from.present?
      users = users.where('users.created_at <= ?', @date_to.to_date.end_of_day) if @date_to.present?
      users
    end

    def apply_sort(users)
      case @sort_by
      when 'game_results_count'
        users.left_joins(:game_results)
             .group('users.id')
             .order(Arel.sql("COUNT(game_results.id) #{@sort_order}"))
      when 'followers_count'
        users.left_joins(:passive_relationships)
             .group('users.id')
             .order(Arel.sql("COUNT(relationships.id) #{@sort_order}"))
      when 'last_login_at'
        users.order(Arel.sql("last_login_at IS NULL ASC, last_login_at #{@sort_order}"))
      when 'name'
        users.order(Arel.sql("(name IS NULL OR name = '') ASC, name #{@sort_order}"))
      else
        users.order(@sort_by => @sort_order)
      end
    end

    def apply_pagination(users)
      offset = (@page - 1) * @per_page
      users.limit(@per_page).offset(offset)
    end
  end
end
