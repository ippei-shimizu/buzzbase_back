module Admin
  class RefreshToken < ApplicationRecord
    self.table_name = 'admin_refresh_tokens'
    belongs_to :admin_user, class_name: 'Admin::User'

    validates :jti, presence: true, uniqueness: true
    validates :expires_at, presence: true

    scope :active, -> { where('expires_at > ? AND revoked_at IS NULL', Time.current) }

    def expired?
      expires_at < Time.current
    end

    def revoked?
      revoked_at.present?
    end

    def active?
      !expired? && !revoked?
    end

    def revoke!
      update!(revoked_at: Time.current)
    end

    def self.cleanup_expired!
      where('expires_at < ?', Time.current).delete_all
    end
  end
end
