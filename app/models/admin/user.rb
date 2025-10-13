module Admin
  class User < ApplicationRecord
    self.table_name = 'admin_users'

    has_secure_password validations: false

    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password, length: { minimum: 6 }, allow_nil: true, on: :update
    validates :password, presence: true, length: { minimum: 6 }, on: :create
    validates :name, presence: true
  end
end
