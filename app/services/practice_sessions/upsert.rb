module PracticeSessions
  # 日次の練習セッションを upsert する。
  # 1日（logged_on）を親に、複数メニューの量ログ（practice_logs / source=manual）と
  # その日のコンディションを一括で保存する。野球ノート形式の「1日の振り返り」入力に対応する。
  #
  # 量ログは practice_menu_id をキーに差分同期する（既存は更新・新規は作成・外れたものは削除）。
  # 素振り自動ログ（source=shadow_swing）は編集対象外なので触らない。
  # コンディションは Pro 限定。ペイロードに含まれ、かつ Pro 未加入なら NotEntitled を投げる。
  class Upsert
    # コンディション記録は Pro 限定のため、未加入時に投げる。
    class NotEntitled < StandardError; end

    # @param user [User]
    # @param logged_on [Date, String]
    # @param memo [String, nil] その日の振り返りメモ
    # @param items [Array<Hash>] [{ practice_menu_id:, amount:, memo: }]
    # @param condition [Hash, nil] コンディション入力（nil なら更新しない）
    def initialize(user:, logged_on:, memo: nil, items: [], condition: nil)
      @user = user
      @logged_on = logged_on
      @memo = memo
      @items = items || []
      @condition = condition
    end

    # @return [PracticeSession] 保存済みセッション
    def call
      session = nil
      ActiveRecord::Base.transaction do
        session = PracticeSession.for(@user, @logged_on)
        session.update!(memo: @memo) unless @memo.nil?
        sync_items(session)
        upsert_condition if @condition.present?
      end
      session.reload
    end

    private

    # メニュー量ログを practice_menu_id ベースで差分同期する。
    def sync_items(session)
      menus = @user.practice_menus.where(id: item_menu_ids).index_by(&:id)
      existing = session.practice_logs.where(source: 'manual').index_by(&:practice_menu_id)
      kept_menu_ids = []

      @items.each do |item|
        menu = menus[item[:practice_menu_id].to_i]
        next if menu.nil?

        kept_menu_ids << menu.id
        attributes = { amount: item[:amount], memo: item[:memo], menu_name: menu.name, unit_label: menu.unit_label }
        if (log = existing[menu.id])
          log.update!(attributes)
        else
          session.practice_logs.create!(attributes.merge(user: @user, logged_on: @logged_on, practice_menu: menu))
        end
      end

      existing.each_value { |log| log.destroy! unless kept_menu_ids.include?(log.practice_menu_id) }
    end

    def upsert_condition
      raise NotEntitled unless @user.has_entitlement?('detailed_condition_log')

      log = @user.condition_logs.find_or_initialize_by(logged_on: @logged_on)
      log.update!(@condition.merge(logged_on: @logged_on))
    end

    def item_menu_ids
      @items.filter_map { |item| item[:practice_menu_id] }
    end
  end
end
