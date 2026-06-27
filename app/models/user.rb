class User < ActiveRecord::Base # rubocop:disable Metrics/ClassLength
  include Entitlement
  include PlanLimits
  include SubscriptionCallbacks

  mount_uploader :image, AvatarUploader
  has_one :subscription, dependent: :destroy
  has_many :user_subscription_events, dependent: :destroy
  has_many :cancellation_feedbacks, dependent: :destroy
  has_many :user_positions, dependent: :destroy
  has_many :positions, through: :user_positions
  belongs_to :team, foreign_key: 'user_id', primary_key: 'id', optional: true, inverse_of: :user
  has_many :user_awards, dependent: :destroy
  has_many :awards, through: :user_awards
  has_many :active_relationships, class_name: 'Relationship', foreign_key: 'follower_id', dependent: :destroy, inverse_of: :follower
  has_many :passive_relationships, class_name: 'Relationship', foreign_key: 'followed_id', dependent: :destroy, inverse_of: :follower
  has_many :following, -> { where(relationships: { status: Relationship.statuses[:accepted] }) }, through: :active_relationships,
                                                                                                  source: :followed
  has_many :followers, -> { where(relationships: { status: Relationship.statuses[:accepted] }) }, through: :passive_relationships,
                                                                                                  source: :follower
  has_many :pending_follow_requests, -> { where(status: :pending) }, class_name: 'Relationship', foreign_key: 'followed_id',
                                                                     dependent: false, inverse_of: :followed
  has_many :sent_follow_requests, -> { where(status: :pending) }, class_name: 'Relationship', foreign_key: 'follower_id',
                                                                  dependent: false, inverse_of: :follower
  has_many :group_users, dependent: :destroy
  has_many :groups, through: :group_users
  has_many :group_invitations, dependent: :destroy
  has_many :group_invite_links, class_name: 'GroupInviteLink', foreign_key: 'inviter_id',
                                dependent: :destroy, inverse_of: :inviter
  has_many :group_ranking_snapshots, dependent: :destroy
  has_many :user_notifications, dependent: :destroy
  has_many :notifications, through: :user_notifications
  has_many :actor_notifications, class_name: 'Notification', foreign_key: 'actor_id',
                                 dependent: :destroy, inverse_of: :actor
  has_many :device_tokens, dependent: :destroy
  has_many :baseball_notes, dependent: :destroy
  has_many :match_results, dependent: :destroy
  has_many :seasons, dependent: :destroy
  has_many :game_results, dependent: :destroy
  has_many :batting_averages, dependent: :destroy
  has_many :pitching_results, dependent: :destroy
  has_many :plate_appearances, dependent: :destroy
  has_many :created_pitchers, class_name: 'Pitcher', foreign_key: 'created_by_user_id', dependent: :destroy, inverse_of: :created_by_user
  has_many :practice_menus, dependent: :destroy
  has_many :practice_logs, dependent: :destroy
  has_many :condition_logs, dependent: :destroy
  has_many :activity_logs, dependent: :destroy
  has_many :shadow_swing_sessions, dependent: :destroy
  has_many :schedules, dependent: :destroy

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable
  include DeviseTokenAuth::Concerns::User

  # devise_token_auth 1.2.6 + Rails 7.1 では `serialize :tokens, coder: TokensSerialization`
  # が json 型カラムに当たって二重シリアライズになり認証が壊れるため、明示的に json 型を当てて
  # coder を打ち消す。default は devise_token_auth が `tokens.fetch(...)` を呼ぶ前提のため
  # 空ハッシュにしておく。
  attribute :tokens, ActiveRecord::Type::Json.new, default: -> { {} }

  # devise_token_auth 1.2.6 の clean_old_tokens は (1) `self.tokens = ...to_h` で Hash を
  # 全置換して attribute tracking と衝突し直前の create_token の代入を消す、(2)
  # max_lifespan_expiry が TokenFactory.expiry と異なる固定 30.4375 日換算のため月によっては
  # 新規 token を delete してしまう、の 2 点が壊れているので、in-place mutation のみと
  # TokenFactory と同式の計算で再実装する。
  def clean_old_tokens
    return if tokens.blank? || !max_client_tokens_exceeded?

    # 旧 lifespan (例えば 6.months) で発行されて token_lifespan より先の expiry を持つ
    # long-lived token を削除する。新規 token の expiry は TokenFactory と同じ式で max と
    # 揃うため新規分は残る。
    max_lifespan_expiry = (Time.zone.now + DeviseTokenAuth.token_lifespan).to_i
    tokens.delete_if { |_cid, v| token_expiry_of(v) > max_lifespan_expiry }

    while max_client_tokens_exceeded?
      oldest_cid, = tokens.min_by { |_cid, v| token_expiry_of(v) }
      break unless oldest_cid

      tokens.delete(oldest_cid)
    end
  end

  before_validation :normalize_user_id
  after_commit :notify_slack_new_user, on: :create

  validates :password, custom_password: true, on: :create, unless: -> { provider.in?(%w[google apple]) }
  validates :user_id, uniqueness: true, allow_blank: true, if: :user_id_changed?
  validates :user_id, format: { with: /\A[A-Za-z0-9_-]+\z/ }, allow_blank: true, if: :user_id_changed?
  validates :user_id, length: { minimum: 3, maximum: 30 }, allow_blank: true, if: :user_id_changed?
  validates :introduction, length: { maximum: 100 }, if: :introduction_changed?

  def password_required?
    return false if provider.in?(%w[google apple])

    super
  end

  def google_account?
    provider == 'google'
  end

  def apple_account?
    provider == 'apple'
  end

  # Apple private relay (@privaterelay.appleid.com) はフォワード不達 + SMTP 上限浪費のため対象外とする。
  def email_deliverable?
    return false if email.blank?

    !email.downcase.end_with?('@privaterelay.appleid.com')
  end

  scope :active, -> { where(suspended_at: nil, deleted_at: nil) }
  scope :suspended, -> { where.not(suspended_at: nil).where(deleted_at: nil) }
  scope :soft_deleted, -> { where.not(deleted_at: nil) }
  scope :not_deleted, -> { where(deleted_at: nil) }

  def account_status
    return 'deleted' if deleted_at.present?
    return 'suspended' if suspended_at.present?

    'active'
  end

  def suspend!(reason = nil)
    update!(suspended_at: Time.current, suspended_reason: reason)
  end

  def restore!
    update!(suspended_at: nil, suspended_reason: nil)
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def following?(other_user)
    following.include?(other_user)
  end

  def follow(other_user, force_accept: false)
    if force_accept || !other_user.is_private?
      active_relationships.create(followed_id: other_user.id, status: :accepted)
    else
      active_relationships.create(followed_id: other_user.id, status: :pending)
    end
  end

  def unfollow(other_user)
    active_relationships.find_by(followed_id: other_user.id)&.destroy
  end

  def follow_request_pending?(other_user)
    active_relationships.pending.exists?(followed_id: other_user.id)
  end

  def follow_status(other_user)
    return 'self' if self == other_user

    relationship = active_relationships.find_by(followed_id: other_user.id)
    return 'none' unless relationship

    relationship.accepted? ? 'following' : 'pending'
  end

  def profile_visible_to?(viewer)
    return true unless is_private?
    return true if viewer == self
    return false unless viewer

    followers.include?(viewer)
  end

  def incoming_follow_request_id_from(other_user)
    return nil unless other_user

    pending_follow_requests.find_by(follower_id: other_user.id)&.id
  end

  def approve_all_pending_requests!
    pending_follow_requests.update_all(status: :accepted) # rubocop:disable Rails/SkipsModelValidations
  end

  delegate :count, to: :following, prefix: true

  delegate :count, to: :followers, prefix: true

  # subscription が未生成の場合に「無料状態」を表す未保存レコードを返す。
  # API レスポンス時に nil チェックを避ける目的で利用する。
  # @return [Subscription]
  def subscription_or_default
    subscription || Subscription.new(user: self, status: 'free')
  end

  # Pro 機能が利用可能か。
  # @return [Boolean]
  delegate :pro_active?, to: :subscription_or_default

  # トライアル期間中か。
  # @return [Boolean]
  delegate :in_trial?, to: :subscription_or_default

  private

  def normalize_user_id
    self.user_id = nil if user_id.blank?
  end

  def notify_slack_new_user
    SlackNotificationService.notify_new_user(self)
  end

  # Symbol/String キーの両方に対応した expiry 取得 (clean_old_tokens で使用)。
  # 万一 nil entry が混入していた場合は 0 を返し、while ループで最古として確実に削除される。
  def token_expiry_of(token_entry)
    return 0 unless token_entry.is_a?(Hash)

    (token_entry[:expiry] || token_entry['expiry']).to_i
  end
end
