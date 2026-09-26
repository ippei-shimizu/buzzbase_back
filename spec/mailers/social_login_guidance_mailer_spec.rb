require 'rails_helper'

RSpec.describe SocialLoginGuidanceMailer, type: :mailer do
  it 'has a display name for every social provider the app accepts' do
    expect(described_class::PROVIDER_NAMES.keys).to match_array(User::SOCIAL_PROVIDERS)
  end

  describe '#password_reset_requested' do
    let(:mail) { described_class.password_reset_requested(user) }

    context 'with a google account' do
      let(:user) { create(:user, :google, email: 'google-user@example.com', uid: 'google-uid-123') }

      it 'is sent only to the account owner without the operator bcc' do
        expect(mail.to).to eq(['google-user@example.com'])
        expect(mail.bcc).to be_blank
      end

      it 'has a subject about how to log in' do
        expect(mail.subject).to include('ログイン方法')
      end

      it 'tells the user to log in with Google in both text and html parts' do
        expect(mail.text_part.decoded).to include('Google でのログインに紐付いている')
        expect(mail.html_part.decoded).to include('Google')
        expect(mail.text_part.decoded).not_to include('Apple')
      end
    end

    context 'with a google account that has set a password' do
      let(:user) do
        create(:user, :google, email: 'google-password@example.com', uid: 'google-uid-password',
                               password: 'password123', password_confirmation: 'password123')
      end

      it 'tells the user to log in with Google and set the password again, in both text and html parts' do
        [mail.text_part.decoded, mail.html_part.decoded].each do |body|
          expect(body).to include('設定画面からパスワードを設定し直してください')
          expect(body).not_to include('パスワードでのログインおよびパスワードの再設定はご利用いただけません')
        end
      end
    end

    context 'with an apple account' do
      let(:user) { create(:user, :apple, email: 'apple-user@example.com', uid: 'apple-uid-123') }

      it 'tells the user to log in with Apple' do
        expect(mail.text_part.decoded).to include('Apple でのログインに紐付いている')
        expect(mail.text_part.decoded).not_to include('Google')
      end
    end
  end
end
