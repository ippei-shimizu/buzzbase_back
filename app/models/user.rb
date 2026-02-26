class User < ActiveRecord::Base
  mount_uploader :image, AvatarUploader
  has_many :user_positions, dependent: :destroy
  has_many :positions, through: :user_positions
  belongs_to :team, foreign_key: 'user_id', primary_key: 'id', optional: true, inverse_of: :team
  has_many :user_awards, dependent: :destroy
  has_many :awards, through: :user_awards
  has_many :active_relationships, class_name: 'Relationship', foreign_key: 'follower_id', dependent: :destroy, inverse_of: :follower
  has_many :passive_relationships, class_name: 'Relationship', foreign_key: 'followed_id', dependent: :destroy, inverse_of: :follower
  has_many :following, through: :active_relationships, source: :followed
  has_many :followers, through: :passive_relationships, source: :follower
  has_many :group_users, dependent: :destroy
  has_many :groups, through: :group_users
  has_many :group_invitations, dependent: :destroy
  has_many :user_notifications, dependent: :destroy
  has_many :notifications, through: :user_notifications
  has_many :actor_notifications, class_name: 'Notification', foreign_key: 'actor_id',
                                 dependent: :destroy, inverse_of: :actor
  has_many :baseball_notes, dependent: :destroy
  has_many :match_results, dependent: :destroy
  has_many :game_results, dependent: :destroy
  has_many :batting_averages, dependent: :destroy
  has_many :pitching_results, dependent: :destroy
  has_many :plate_appearances, dependent: :destroy

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable
  include DeviseTokenAuth::Concerns::User

  validates :password, custom_password: true, on: :create
  validates :user_id, uniqueness: true, allow_blank: true
  validates :introduction, length: { maximum: 100 }

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

  def follow(other_user)
    active_relationships.create(followed_id: other_user.id)
  end

  def unfollow(other_user)
    active_relationships.find_by(followed_id: other_user.id).destroy
  end

  delegate :count, to: :following, prefix: true

  delegate :count, to: :followers, prefix: true
end
