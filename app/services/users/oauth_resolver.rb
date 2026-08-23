module Users
  # Google / Apple の検証済みペイロードから User を冪等に解決する。
  # provider+uid 一致 -> email 一致（provider/uid をリンク）-> 新規作成 の順に解決し、
  # 並行リクエストによる一意制約違反は勝者を引き直して吸収する。
  class OauthResolver
    # Apple は2回目以降のサインインで email を返さないため、uid で既存ユーザーを
    # 引けなかった場合にだけ投げる。呼び出し側で provider 固有の文言に翻訳する。
    class EmailMissing < StandardError; end

    # @param provider [String] 'google' または 'apple'
    # @param uid [String] IDトークンの sub
    # @param email [String, nil]
    # @param name [String, nil]
    def initialize(provider:, uid:, email:, name: nil)
      @provider = provider
      @uid = uid
      @email = email
      @name = name
    end

    # @return [User] 既存・リンク済み・新規作成のいずれかのユーザー
    # @raise [EmailMissing] uid で引けず email も無い場合
    def call
      existing_user = find_by_provider_uid
      return existing_user if existing_user

      raise EmailMissing if @email.blank?

      # 一意制約違反は外側のトランザクションごと中断させるため、復旧クエリを流せるよう
      # セーブポイント内で書き込む。
      ActiveRecord::Base.transaction(requires_new: true) do
        linked_user = find_by_email
        linked_user ? link_provider!(linked_user) : create_user!
      end
    rescue ActiveRecord::RecordNotUnique => e
      # 同一 email / uid が並行到達したときの敗者側。勝者は必ず provider+uid を満たすため
      # そこから引き直す。引けないなら email / uid 以外の制約違反なので握り潰さず投げ直す。
      Rails.logger.warn("OAuth sign-in race recovered: provider=#{@provider}")
      find_by_provider_uid || find_by_email || raise(e)
    end

    private

    def find_by_provider_uid
      User.find_by(provider: @provider, uid: @uid)
    end

    def find_by_email
      User.find_by(email: @email)
    end

    def link_provider!(user)
      attributes = { provider: @provider, uid: @uid }
      attributes[:confirmed_at] = Time.current if user.confirmed_at.blank?
      user.update!(attributes)
      user
    end

    def create_user!
      User.create!(
        email: @email,
        provider: @provider,
        uid: @uid,
        name: @name,
        confirmed_at: Time.current
      )
    end
  end
end
