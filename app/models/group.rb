class Group < ApplicationRecord
  mount_uploader :icon, GroupIconUploader
  # User#image と同様、S3 への転送をトランザクションの外（COMMIT 後）で行う。
  skip_callback :save, :after, :store_icon!
  after_commit :store_icon_after_commit, on: %i[create update]
  has_many :group_users, dependent: :destroy
  has_many :users, through: :group_users
  has_many :group_invitations, dependent: :destroy
  has_many :group_invite_links, dependent: :destroy

  validates :name, presence: true

  def accepted_users
    group_invitations.includes(:user).where(state: 'accepted').map(&:user)
  end

  def update_users_by_ids(user_ids)
    invited_users = []

    ActiveRecord::Base.transaction do
      current_user_ids = group_invitations.where(state: 'accepted').pluck(:user_id)
      new_user_ids = user_ids - current_user_ids
      removed_user_ids = current_user_ids - user_ids.map(&:to_i)

      new_user_ids.each do |user_id|
        user = User.find_by(id: user_id)
        next unless user

        invited_users << user if invite_user(user)
      end

      removed_user_ids.each do |user_id|
        group_invitations.where(user_id:).destroy_all
      end
    end

    invited_users
  end

  private

  # COMMIT 後の転送失敗は行ごと巻き戻せないため、実体の無いファイル名がカラムに残らないよう
  # 直前の識別子へ戻してから例外を再送出する。
  def store_icon_after_commit
    store_icon!
  rescue StandardError
    update_column(:icon, saved_changes['icon']&.first) if saved_changes.key?('icon') # rubocop:disable Rails/SkipsModelValidations
    raise
  end

  def invite_user(user)
    invitation = group_invitations.find_or_initialize_by(user_id: user.id)
    return false unless invitation.new_record?

    invitation.state = 'pending'
    invitation.sent_at = Time.current
    invitation.save!
    true
  end
end
