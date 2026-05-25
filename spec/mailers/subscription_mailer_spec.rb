require 'rails_helper'

RSpec.describe SubscriptionMailer, type: :mailer do
  let(:user) { create(:user, name: '翔太', email: 'shota@example.com') }

  shared_examples 'BUZZ BASE 運営 BCC を含まないこと' do
    it 'bcc が空であること（個人情報保護のため運営アドレスを外す）' do
      expect(mail.bcc).to be_blank
    end

    it '送信元が BUZZ BASE 運営であること' do
      expect(mail.from).to include('BUZZ BASE運営')
    end

    it '宛先が user.email であること' do
      expect(mail.to).to eq([user.email])
    end
  end

  describe '#trial_expiring_soon' do
    let(:subscription) { user.subscription.tap { |s| s.update!(status: 'trial', expires_at: 3.days.from_now) } }
    let(:mail) do
      subscription
      described_class.trial_expiring_soon(user)
    end

    include_examples 'BUZZ BASE 運営 BCC を含まないこと'

    it '件名にトライアル終了の予告が含まれる' do
      expect(mail.subject).to include('トライアル終了')
    end

    it '本文（text）に user.name が含まれる' do
      expect(mail.text_part.body.to_s).to include(user.name)
    end
  end

  describe '#pro_expiring_soon' do
    let(:mail) do
      user.subscription.update!(status: 'cancelled', expires_at: 3.days.from_now)
      described_class.pro_expiring_soon(user)
    end

    include_examples 'BUZZ BASE 運営 BCC を含まないこと'

    it '件名に Pro 期間終了の予告が含まれる' do
      expect(mail.subject).to include('Pro')
      expect(mail.subject).to include('終了')
    end
  end

  describe '#cancelled' do
    let(:mail) do
      user.subscription.update!(status: 'cancelled', expires_at: 30.days.from_now, cancelled_at: Time.current)
      described_class.cancelled(user)
    end

    include_examples 'BUZZ BASE 運営 BCC を含まないこと'

    it '件名に解約完了が含まれる' do
      expect(mail.subject).to include('解約')
    end
  end

  describe '#expired' do
    let(:mail) do
      user.subscription.update!(status: 'expired', expires_at: 1.day.ago)
      described_class.expired(user)
    end

    include_examples 'BUZZ BASE 運営 BCC を含まないこと'

    it '件名に Pro 期間終了が含まれる' do
      expect(mail.subject).to include('終了')
    end
  end

  describe '#billing_issue' do
    let(:mail) do
      user.subscription.update!(status: 'billing_issue', billing_issue_at: Time.current, expires_at: 5.days.from_now)
      described_class.billing_issue(user)
    end

    include_examples 'BUZZ BASE 運営 BCC を含まないこと'

    it '件名に決済情報の確認を促す文言が含まれる' do
      expect(mail.subject).to include('決済')
    end
  end

  describe '#refunded' do
    let(:mail) do
      user.subscription.update!(status: 'expired', refunded_at: Time.current, expires_at: Time.current)
      described_class.refunded(user)
    end

    include_examples 'BUZZ BASE 運営 BCC を含まないこと'

    it '件名に返金完了が含まれる' do
      expect(mail.subject).to include('返金')
    end
  end

  describe '#recovered' do
    let(:mail) do
      user.subscription.update!(status: 'active', expires_at: 30.days.from_now)
      described_class.recovered(user)
    end

    include_examples 'BUZZ BASE 運営 BCC を含まないこと'

    it '件名に再開が含まれる' do
      expect(mail.subject).to include('再開')
    end
  end
end
