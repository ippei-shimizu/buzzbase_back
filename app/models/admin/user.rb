module Admin
  class User < ApplicationRecord
    self.table_name = 'admin_users'

    has_secure_password validations: false
    has_many :management_notices, foreign_key: :created_by_id, dependent: :restrict_with_error, inverse_of: :created_by

    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password, length: { minimum: 6 }, allow_nil: true, on: :update
    validates :password, presence: true, length: { minimum: 6 }, on: :create
    validates :name, presence: true
  end
end
