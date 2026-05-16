require 'rails_helper'

RSpec.describe PushNotificationService do
  let(:user) { create(:user) }

  describe '.send_to_user' do
    context 'when user has no device tokens' do
      it 'does not call the push notification client' do
        client_double = instance_double(Exponent::Push::Client)
        allow(Exponent::Push::Client).to receive(:new).and_return(client_double)
        allow(client_double).to receive(:send_messages)

        described_class.send_to_user(user, title: 'Test', body: 'Test body')

        expect(client_double).not_to have_received(:send_messages)
      end
    end

    context 'when user has device tokens' do
      before do
        user.device_tokens.create!(token: 'ExponentPushToken[test-token-1]', platform: 'ios')
        user.device_tokens.create!(token: 'ExponentPushToken[test-token-2]', platform: 'android')
      end

      it 'sends push notifications to all device tokens' do
        client_double = instance_double(Exponent::Push::Client)
        allow(Exponent::Push::Client).to receive(:new).and_return(client_double)
        allow(client_double).to receive(:send_messages)

        described_class.send_to_user(user, title: 'BUZZ BASE', body: '通知メッセージ')

        expect(client_double).to have_received(:send_messages) do |messages|
          expect(messages.length).to eq(2)
          expect(messages.first[:title]).to eq('BUZZ BASE')
          expect(messages.first[:body]).to eq('通知メッセージ')
          expect(messages.first[:sound]).to eq('default')
          tokens = messages.pluck(:to)
          expect(tokens).to include('ExponentPushToken[test-token-1]', 'ExponentPushToken[test-token-2]')
        end
      end

      it 'builds messages with the correct structure' do
        client_double = instance_double(Exponent::Push::Client)
        allow(Exponent::Push::Client).to receive(:new).and_return(client_double)
        allow(client_double).to receive(:send_messages)

        described_class.send_to_user(user, title: 'タイトル', body: 'ボディ')

        expect(client_double).to have_received(:send_messages) do |messages|
          messages.each do |message|
            expect(message).to have_key(:to)
            expect(message).to have_key(:title)
            expect(message).to have_key(:body)
            expect(message).to have_key(:sound)
          end
        end
      end
    end

    context 'when the push notification client raises an error' do
      before do
        user.device_tokens.create!(token: 'ExponentPushToken[test-token]', platform: 'ios')
      end

      it 'logs the error and does not raise' do
        client_double = instance_double(Exponent::Push::Client)
        allow(Exponent::Push::Client).to receive(:new).and_return(client_double)
        allow(client_double).to receive(:send_messages).and_raise(StandardError, 'network error')
        allow(Rails.logger).to receive(:error)

        expect do
          described_class.send_to_user(user, title: 'Test', body: 'Test')
        end.not_to raise_error

        expect(Rails.logger).to have_received(:error).with('Push notification failed: network error')
      end
    end
  end

  describe '.send_to_all' do
    let(:client_double) { instance_double(Exponent::Push::Client) }
    let(:handler_double) { instance_double(Exponent::Push::ResponseHandler, errors?: false) }

    before do
      allow(Exponent::Push::Client).to receive(:new).and_return(client_double)
      allow(client_double).to receive(:send_messages).and_return(handler_double)
    end

    context 'DeviceToken が0件の場合' do
      it 'send_messages を呼び出さない' do
        described_class.send_to_all(title: 'タイトル', body: '本文')
        expect(client_double).not_to have_received(:send_messages)
      end
    end

    context 'DeviceToken が99件の場合' do
      before do
        users = create_list(:user, 99)
        users.each_with_index do |u, i|
          u.device_tokens.create!(token: "ExponentPushToken[t#{i}]", platform: 'ios')
        end
      end

      it 'send_messages が1回だけ呼ばれる' do
        described_class.send_to_all(title: 'タイトル', body: '本文')
        expect(client_double).to have_received(:send_messages).once
      end
    end

    context 'DeviceToken が101件の場合（100件チャンクの境界）' do
      before do
        users = create_list(:user, 101)
        users.each_with_index do |u, i|
          u.device_tokens.create!(token: "ExponentPushToken[t#{i}]", platform: 'ios')
        end
      end

      it 'send_messages が2回呼ばれる（100件 + 1件）' do
        described_class.send_to_all(title: 'タイトル', body: '本文')
        expect(client_double).to have_received(:send_messages).twice
      end
    end

    context 'ResponseHandler が errors? を返す場合' do
      let(:handler_double) do
        instance_double(
          Exponent::Push::ResponseHandler,
          errors?: true,
          errors: [{ message: 'invalid token' }],
          invalid_push_tokens: ['ExponentPushToken[bad]']
        )
      end

      before do
        user = create(:user)
        user.device_tokens.create!(token: 'ExponentPushToken[t1]', platform: 'ios')
        allow(Rails.logger).to receive(:error)
      end

      it 'エラーをログに記録し、例外を raise しない' do
        expect do
          described_class.send_to_all(title: 'タイトル', body: '本文')
        end.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(/send_to_all errors/)
      end
    end

    context 'send_messages が例外を raise した場合' do
      before do
        user = create(:user)
        user.device_tokens.create!(token: 'ExponentPushToken[t1]', platform: 'ios')
        allow(client_double).to receive(:send_messages).and_raise(StandardError, 'network error')
        allow(Rails.logger).to receive(:error)
      end

      it '例外が伝播する' do
        expect do
          described_class.send_to_all(title: 'タイトル', body: '本文')
        end.to raise_error(StandardError, 'network error')

        expect(Rails.logger).to have_received(:error).with(/send_batch failed/)
      end
    end
  end
end
