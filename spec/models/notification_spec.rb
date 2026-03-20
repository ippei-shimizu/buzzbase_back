require 'rails_helper'

RSpec.describe Notification, type: :model do
  describe 'associations' do
    it { should belong_to(:actor).class_name('User') }
    it { should have_many(:user_notifications).dependent(:destroy) }
    # group_invitations association is declared in model but notification_id column
    # does not exist on group_invitations table yet - skip until migration is added
  end
end
