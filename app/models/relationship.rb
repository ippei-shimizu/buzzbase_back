class Relationship < ApplicationRecord
  belongs_to :follower, class_name: 'User'
  belongs_to :followed, class_name: 'User'

  enum status: { pending: 0, accepted: 1 }

  scope :accepted, -> { where(status: :accepted) }
  scope :pending, -> { where(status: :pending) }
end
