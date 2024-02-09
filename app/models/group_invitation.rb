class GroupInvitation < ApplicationRecord
  belongs_to :user
  belongs_to :group

  validates :state, presence: true

  enum state: { pending: 0, accepted: 1, declined: 2 }
end
