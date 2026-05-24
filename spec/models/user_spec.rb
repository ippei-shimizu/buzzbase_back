require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'user_id validations' do
    describe 'uniqueness' do
      it 'allows unique user_id' do
        create(:user, user_id: 'player_one')
        user = build(:user, user_id: 'player_two')
        expect(user).to be_valid
      end

      it 'rejects duplicate user_id' do
        create(:user, user_id: 'player_one')
        user = build(:user, user_id: 'player_one')
        expect(user).not_to be_valid
        expect(user.errors[:user_id]).to include('このユーザーIDは既に使われています')
      end

      it 'allows blank user_id' do
        user = build(:user, user_id: '')
        expect(user.errors[:user_id]).to be_empty
      end

      it 'normalizes empty string user_id to nil on save' do
        user = create(:user, user_id: '')
        expect(user.reload.user_id).to be_nil
      end

      it 'normalizes whitespace-only user_id to nil on save' do
        user = create(:user, user_id: '   ')
        expect(user.reload.user_id).to be_nil
      end

      it 'allows multiple users with blank user_id (BUZZBASE-BACKEND-P regression)' do
        create(:user, user_id: '')
        expect { create(:user, user_id: '') }.not_to raise_error
        expect(described_class.where(user_id: nil).count).to be >= 2
      end
    end

    describe 'format' do
      it 'allows alphanumeric characters' do
        user = build(:user, user_id: 'Player123')
        expect(user).to be_valid
      end

      it 'allows hyphens and underscores' do
        user = build(:user, user_id: 'my-user_name')
        expect(user).to be_valid
      end

      it 'rejects Japanese characters' do
        user = build(:user, user_id: 'ユーザー名')
        expect(user).not_to be_valid
        expect(user.errors[:user_id]).to be_present
      end

      it 'rejects spaces' do
        user = build(:user, user_id: 'my name')
        expect(user).not_to be_valid
      end

      it 'rejects special characters' do
        user = build(:user, user_id: 'user@name!')
        expect(user).not_to be_valid
      end
    end

    describe 'length' do
      it 'rejects user_id shorter than 3 characters' do
        user = build(:user, user_id: 'ab')
        expect(user).not_to be_valid
        expect(user.errors[:user_id]).to be_present
      end

      it 'allows user_id with exactly 3 characters' do
        user = build(:user, user_id: 'abc')
        expect(user).to be_valid
      end

      it 'allows user_id with exactly 30 characters' do
        user = build(:user, user_id: 'a' * 30)
        expect(user).to be_valid
      end

      it 'rejects user_id longer than 30 characters' do
        user = build(:user, user_id: 'a' * 31)
        expect(user).not_to be_valid
        expect(user.errors[:user_id]).to be_present
      end
    end

    describe 'user_id update' do
      it 'allows changing user_id to a new valid value' do
        user = create(:user, user_id: 'old_slug')
        user.user_id = 'new_slug'
        expect(user).to be_valid
        expect(user.save).to be true
        expect(user.reload.user_id).to eq('new_slug')
      end

      it 'rejects changing user_id to an existing one' do
        create(:user, user_id: 'taken_slug')
        user = create(:user, user_id: 'my_slug')
        user.user_id = 'taken_slug'
        expect(user).not_to be_valid
      end

      it 'preserves associated data after user_id change' do
        user = create(:user, user_id: 'old_slug')
        original_id = user.id
        user.update!(user_id: 'new_slug')
        expect(user.reload.id).to eq(original_id)
      end
    end

    # Bug #247 (BUZZBASE-BACKEND-M) リグレッション
    # ログイン時の save! でレガシー値（バリデーション追加前の short user_id）が
    # RecordInvalid を発火させて500になっていた。user_id を変更しない save では
    # バリデーションを走らせないことで grandfather する。
    describe 'legacy user_id (BUZZBASE-BACKEND-M regression)' do
      it 'allows save! when legacy user_id is shorter than 3 chars and unchanged' do
        user = create(:user, user_id: 'valid_id')
        user.update_column(:user_id, 'ab') # rubocop:disable Rails/SkipsModelValidations

        user.reload
        expect { user.save! }.not_to raise_error
      end

      it 'allows save! when legacy user_id is longer than 30 chars and unchanged' do
        user = create(:user, user_id: 'valid_id')
        user.update_column(:user_id, 'a' * 35) # rubocop:disable Rails/SkipsModelValidations

        user.reload
        expect { user.save! }.not_to raise_error
      end

      it 'still rejects when user_id is being changed to an invalid value' do
        user = create(:user, user_id: 'valid_id')
        user.user_id = 'ab'
        expect(user).not_to be_valid
        expect(user.errors[:user_id]).to be_present
      end
    end
  end

  describe 'introduction validations' do
    it 'allows save! when legacy introduction exceeds 100 chars and unchanged' do
      user = create(:user)
      user.update_column(:introduction, 'a' * 200) # rubocop:disable Rails/SkipsModelValidations

      user.reload
      expect { user.save! }.not_to raise_error
    end

    it 'still rejects when introduction is being changed to over 100 chars' do
      user = create(:user)
      user.introduction = 'a' * 101
      expect(user).not_to be_valid
      expect(user.errors[:introduction]).to be_present
    end
  end

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

    describe '#incoming_follow_request_id_from' do
      it 'returns the relationship id when a pending request exists from the other user' do
        requester = create(:user)
        relationship = Relationship.create!(follower: requester, followed: private_user, status: :pending)

        expect(private_user.incoming_follow_request_id_from(requester)).to eq(relationship.id)
      end

      it 'returns nil when no pending request exists from the other user' do
        expect(private_user.incoming_follow_request_id_from(non_follower)).to be_nil
      end

      it 'returns nil when the relationship is already accepted' do
        expect(private_user.incoming_follow_request_id_from(follower)).to be_nil
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

  describe '#create_new_auth_token' do
    let(:user) { create(:user) }

    it 'persists tokens as a Hash without double-encoding on repeated calls' do
      user.create_new_auth_token
      user.create_new_auth_token

      user.reload
      expect(user.tokens).to be_a(Hash)
      expect(user.tokens.values).to all(be_a(Hash))
    end

    context 'when tokens count is at max_devices' do
      let(:max_devices) { DeviseTokenAuth.max_number_of_devices }

      before do
        full_set = (1..max_devices).each_with_object({}) do |i, h|
          h["client_#{i}"] = { 'token' => 'hash', 'expiry' => Time.now.to_i + 60 + i }
        end
        user.update_columns(tokens: full_set) # rubocop:disable Rails/SkipsModelValidations
        user.reload
      end

      it 'does not raise when adding a new token' do
        expect { user.create_new_auth_token }.not_to raise_error
      end

      it 'keeps the newly created client_id and stays within max_devices' do
        headers = user.create_new_auth_token
        user.reload
        expect(user.tokens.keys.count).to eq(max_devices)
        expect(user.tokens.keys).to include(headers['client'])
      end
    end

    context 'when tokens contain a legacy long-lived entry beyond the current lifespan' do
      let(:max_devices) { DeviseTokenAuth.max_number_of_devices }

      before do
        # client_1 だけ旧 6ヶ月 expiry (現行 token_lifespan より遥かに先)、残りは正常範囲
        full_set = (1..max_devices).each_with_object({}) do |i, h|
          expiry = i == 1 ? Time.now.to_i + 6.months.to_i : Time.now.to_i + 60 + i
          h["client_#{i}"] = { 'token' => 'hash', 'expiry' => expiry }
        end
        user.update_columns(tokens: full_set) # rubocop:disable Rails/SkipsModelValidations
        user.reload
      end

      it 'drops the long-lived entry via delete_if before the max_devices loop' do
        user.create_new_auth_token
        user.reload
        expect(user.tokens.keys).not_to include('client_1')
      end
    end
  end

  describe '#sync_stripe_customer_email (after_update)' do
    let(:user) { create(:user, email: 'old@example.com') }
    let(:job) { instance_double(StripeCustomerUpdateJob, perform: nil) }

    before do
      allow(StripeCustomerUpdateJob).to receive(:new).and_return(job)
    end

    context 'Web ユーザーで stripe_customer_id が紐付き、email が変わったとき' do
      before do
        user.subscription.update!(platform: 'web', stripe_customer_id: 'cus_test_abc')
      end

      it 'StripeCustomerUpdateJob を起動する' do
        user.skip_reconfirmation!
        user.update!(email: 'new@example.com')
        expect(job).to have_received(:perform).with(user.id)
      end
    end

    context 'iOS ユーザーのとき' do
      before do
        user.subscription.update!(platform: 'ios', stripe_customer_id: 'cus_ios_abc')
      end

      it 'Stripe Customer 同期を起動しない（Apple ID 側で管理される）' do
        user.skip_reconfirmation!
        user.update!(email: 'new@example.com')
        expect(job).not_to have_received(:perform)
      end
    end

    context 'stripe_customer_id が未紐付のとき' do
      before do
        user.subscription.update!(platform: 'web', stripe_customer_id: nil)
      end

      it 'Stripe Customer 同期を起動しない' do
        user.skip_reconfirmation!
        user.update!(email: 'new@example.com')
        expect(job).not_to have_received(:perform)
      end
    end

    context 'email を変えていないとき' do
      before do
        user.subscription.update!(platform: 'web', stripe_customer_id: 'cus_test_abc')
      end

      it 'Stripe Customer 同期を起動しない' do
        user.update!(name: '別名前')
        expect(job).not_to have_received(:perform)
      end
    end
  end
end
