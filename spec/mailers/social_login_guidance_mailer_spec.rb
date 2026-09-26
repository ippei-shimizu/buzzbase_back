require 'rails_helper'

RSpec.describe SocialLoginGuidanceMailer, type: :mailer do
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

    context 'with an apple account' do
      let(:user) { create(:user, :apple, email: 'apple-user@example.com', uid: 'apple-uid-123') }

      it 'tells the user to log in with Apple' do
        expect(mail.text_part.decoded).to include('Apple でのログインに紐付いている')
        expect(mail.text_part.decoded).not_to include('Google')
      end
    end
  end
end
