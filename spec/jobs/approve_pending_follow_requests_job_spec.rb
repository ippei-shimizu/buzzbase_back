require 'rails_helper'

RSpec.describe ApprovePendingFollowRequestsJob, type: :job do
  describe '#perform' do
    let(:user) { create(:user, is_private: false) }
    let(:requester) { create(:user) }

    before do
      Relationship.create!(follower: requester, followed: user, status: :pending)
    end

    it '承認待ちフォローリクエストを一括承認する' do
      described_class.perform_now(user.id)

      expect(Relationship.pending.where(followed_id: user.id).count).to eq(0)
      expect(Relationship.accepted.where(followed_id: user.id).count).to eq(1)
    end

    it 'ジョブ実行前に非公開へ戻していた場合は承認しない' do
      user.update!(is_private: true)

      described_class.perform_now(user.id)

      expect(Relationship.pending.where(followed_id: user.id).count).to eq(1)
    end

    it 'ユーザーが存在しない場合は何もしない' do
      expect { described_class.perform_now(0) }.not_to raise_error
    end
  end
end
