require 'rails_helper'

RSpec.describe EmailAuthenticationMailer, type: :mailer do
  before do
    ActionMailer::Base.default_url_options = { host: 'localhost:3000' }
  end

  describe '#send_when_signup' do
    context 'when the user has a name' do
      let(:user) { create(:user, name: 'テストユーザー') }
      let(:mail) { described_class.send_when_signup(user) }

      it 'greets the user by name' do
        expect(mail.text_part.decoded).to include('テストユーザー 様')
        expect(mail.html_part.decoded).to include('テストユーザー 様')
      end
    end

    context 'when the user has no name yet (name is set on a later screen)' do
      let(:user) { create(:user, name: nil) }
      let(:mail) { described_class.send_when_signup(user) }

      it 'does not render a bare "様" and falls back to a generic greeting' do
        expect(mail.text_part.decoded).not_to include(' 様')
        expect(mail.text_part.decoded).to include('BUZZ BASEにご登録いただきありがとうございます')
        expect(mail.html_part.decoded).not_to include(' 様')
        expect(mail.html_part.decoded).to include('BUZZ BASEにご登録いただきありがとうございます')
      end
    end
  end
end
