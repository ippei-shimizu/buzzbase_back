require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'scopes' do
    let!(:active_user) { create(:user) }
    let!(:suspended_user) { create(:user, suspended_at: Time.current, suspended_reason: 'test') }
    let!(:deleted_user) { create(:user, deleted_at: Time.current) }

    describe '.active' do
      it 'returns users without suspended_at and deleted_at' do
        expect(described_class.active).to include(active_user)
        expect(described_class.active).not_to include(suspended_user, deleted_user)
      end
    end

    describe '.suspended' do
      it 'returns users with suspended_at' do
        expect(described_class.suspended).to include(suspended_user)
        expect(described_class.suspended).not_to include(active_user, deleted_user)
      end
    end

    describe '.soft_deleted' do
      it 'returns users with deleted_at' do
        expect(described_class.soft_deleted).to include(deleted_user)
        expect(described_class.soft_deleted).not_to include(active_user, suspended_user)
      end
    end
  end

  describe '#account_status' do
    it 'returns "active" for normal users' do
      user = create(:user)
      expect(user.account_status).to eq('active')
    end

    it 'returns "suspended" for suspended users' do
      user = create(:user, suspended_at: Time.current)
      expect(user.account_status).to eq('suspended')
    end

    it 'returns "deleted" for soft-deleted users' do
      user = create(:user, deleted_at: Time.current)
      expect(user.account_status).to eq('deleted')
    end
  end

  describe '#suspend!' do
    it 'sets suspended_at and suspended_reason' do
      user = create(:user)
      user.suspend!('violation')
      expect(user.suspended_at).to be_present
      expect(user.suspended_reason).to eq('violation')
    end
  end

  describe '#restore!' do
    it 'clears suspended_at and suspended_reason' do
      user = create(:user, suspended_at: Time.current, suspended_reason: 'test')
      user.restore!
      expect(user.suspended_at).to be_nil
      expect(user.suspended_reason).to be_nil
    end
  end

  describe 'private account features' do
    let(:public_user) { create(:user, is_private: false) }
    let(:private_user) { create(:user, is_private: true) }
    let(:follower) { create(:user) }
    let(:non_follower) { create(:user) }

    before do
      Relationship.create!(follower:, followed: private_user, status: :accepted)
    end

    describe '#follow' do
      it 'creates an accepted relationship for public users' do
        other_user = create(:user, is_private: false)
        relationship = follower.follow(other_user)
        expect(relationship.status).to eq('accepted')
      end

      it 'creates a pending relationship for private users' do
        other_private = create(:user, is_private: true)
        relationship = follower.follow(other_private)
        expect(relationship.status).to eq('pending')
      end
    end

    describe '#following' do
      it 'only includes accepted relationships' do
        target = create(:user)
        Relationship.create!(follower:, followed: target, status: :accepted)

        pending_target = create(:user, is_private: true)
        Relationship.create!(follower:, followed: pending_target, status: :pending)

        expect(follower.following).to include(target, private_user)
        expect(follower.following).not_to include(pending_target)
      end
    end

    describe '#followers' do
      it 'only includes accepted relationships' do
        Relationship.create!(follower: non_follower, followed: private_user, status: :pending)

        expect(private_user.followers).to include(follower)
        expect(private_user.followers).not_to include(non_follower)
      end
    end

    describe '#follow_status' do
      it 'returns "self" for the user themselves' do
        expect(public_user.follow_status(public_user)).to eq('self')
      end

      it 'returns "following" for an accepted relationship' do
        expect(follower.follow_status(private_user)).to eq('following')
      end

      it 'returns "pending" for a pending relationship' do
        pending_user = create(:user, is_private: true)
        Relationship.create!(follower:, followed: pending_user, status: :pending)
        expect(follower.follow_status(pending_user)).to eq('pending')
      end

      it 'returns "none" when no relationship exists' do
        expect(non_follower.follow_status(public_user)).to eq('none')
      end
    end

    describe '#follow_request_pending?' do
      it 'returns true when a pending request exists' do
        pending_user = create(:user, is_private: true)
        Relationship.create!(follower:, followed: pending_user, status: :pending)
        expect(follower.follow_request_pending?(pending_user)).to be true
      end

      it 'returns false when no pending request exists' do
        expect(follower.follow_request_pending?(private_user)).to be false
      end
    end

    describe '#profile_visible_to?' do
      context 'when user is public' do
        it 'returns true for any viewer' do
          expect(public_user.profile_visible_to?(non_follower)).to be true
        end

        it 'returns true for nil viewer' do
          expect(public_user.profile_visible_to?(nil)).to be true
        end
      end

      context 'when user is private' do
        it 'returns true for the user themselves' do
          expect(private_user.profile_visible_to?(private_user)).to be true
        end

        it 'returns true for accepted followers' do
          expect(private_user.profile_visible_to?(follower)).to be true
        end

        it 'returns false for non-followers' do
          expect(private_user.profile_visible_to?(non_follower)).to be false
        end

        it 'returns false for nil viewer' do
          expect(private_user.profile_visible_to?(nil)).to be false
        end

        it 'returns false for pending followers' do
          pending_follower = create(:user)
          Relationship.create!(follower: pending_follower, followed: private_user, status: :pending)
          expect(private_user.profile_visible_to?(pending_follower)).to be false
        end
      end
    end

    describe '#approve_all_pending_requests!' do
      it 'accepts all pending follow requests' do
        requester1 = create(:user)
        requester2 = create(:user)
        Relationship.create!(follower: requester1, followed: private_user, status: :pending)
        Relationship.create!(follower: requester2, followed: private_user, status: :pending)

        private_user.approve_all_pending_requests!

        expect(Relationship.pending.where(followed_id: private_user.id).count).to eq(0)
        expect(private_user.followers).to include(requester1, requester2)
      end
    end
  end
end
