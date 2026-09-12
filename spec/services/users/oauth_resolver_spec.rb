require 'rails_helper'

RSpec.describe Users::OauthResolver do
  let(:uid) { '110000000000000000001' }
  let(:email) { 'google-user@example.com' }

  describe '#call' do
    context 'provider と uid が一致する既存ユーザーがいる場合' do
      let!(:existing_user) { create(:user, :google, uid:, email:) }

      it '既存ユーザーを返し新規作成しない' do
        expect do
          expect(described_class.new(provider: 'google', uid:, email:, name: '山田 太郎').call).to eq(existing_user)
        end.not_to change(User, :count)
      end
    end

    context 'email が一致する既存ユーザーがいる場合' do
      it 'provider と uid をリンクして返す' do
        existing_user = create(:user, provider: 'email', uid: email, email:)

        expect do
          described_class.new(provider: 'google', uid:, email:, name: '山田 太郎').call
        end.not_to change(User, :count)

        expect(existing_user.reload).to have_attributes(provider: 'google', uid:)
      end

      it '未確認ユーザーなら confirmed_at を埋める' do
        existing_user = create(:user, :unconfirmed, provider: 'email', uid: email, email:)

        described_class.new(provider: 'google', uid:, email:, name: '山田 太郎').call

        expect(existing_user.reload.confirmed_at).to be_present
      end

      it '確認済みユーザーの confirmed_at は上書きしない' do
        confirmed_at = 3.days.ago
        existing_user = create(:user, provider: 'email', uid: email, email:, confirmed_at:)

        described_class.new(provider: 'google', uid:, email:, name: '山田 太郎').call

        expect(existing_user.reload.confirmed_at).to be_within(1.second).of(confirmed_at)
      end
    end

    context '該当するユーザーがいない場合' do
      it 'confirmed_at 付きで新規作成する' do
        expect do
          described_class.new(provider: 'google', uid:, email:, name: '山田 太郎').call
        end.to change(User, :count).by(1)

        expect(User.last).to have_attributes(provider: 'google', uid:, email:, name: '山田 太郎')
        expect(User.last.confirmed_at).to be_present
      end

      it 'apple でも同じ経路で作成される' do
        described_class.new(provider: 'apple', uid:, email:, name: '山田 太郎').call

        expect(User.last).to have_attributes(provider: 'apple', uid:)
      end
    end

    context 'email に大文字・前後の空白が含まれる場合' do
      it '正規化して既存ユーザーを引き当てる' do
        existing_user = create(:user, provider: 'email', uid: email, email:)

        expect do
          described_class.new(provider: 'google', uid:, email: '  Google-User@Example.COM  ', name: '山田 太郎').call
        end.not_to change(User, :count)

        expect(existing_user.reload.provider).to eq('google')
      end

      it '新規作成時は正規化した email で保存する' do
        described_class.new(provider: 'google', uid:, email: '  Google-User@Example.COM  ', name: '山田 太郎').call

        expect(User.last.email).to eq(email)
      end
    end

    context 'email が空の場合' do
      it 'uid でも引けなければ EmailMissing を投げる' do
        expect do
          described_class.new(provider: 'apple', uid:, email: nil, name: nil).call
        end.to raise_error(described_class::EmailMissing)
      end

      it 'uid で引ければ既存ユーザーを返す' do
        existing_user = create(:user, :apple, uid:, email:)

        expect(described_class.new(provider: 'apple', uid:, email: nil, name: nil).call).to eq(existing_user)
      end
    end

    context '同一 email が並行到達して一意制約に負けた場合' do
      it 'INSERT が競合しても勝者のユーザーを返す' do
        winner = create(:user, :google, uid:, email:)
        # SELECT の後・INSERT の前に勝者がコミットした敗者側を再現する。
        allow(User).to receive(:find_by).and_return(nil, nil, winner)
        allow(User).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

        expect(described_class.new(provider: 'google', uid:, email:, name: '山田 太郎').call).to eq(winner)
      end

      it 'リンクの UPDATE が競合しても勝者のユーザーを返す' do
        # 勝者が先に provider+uid を確保し、こちらは別レコードへのリンクに失敗する状況。
        winner = create(:user, :google, uid:, email: 'winner@example.com')
        linked_user = create(:user, provider: 'email', uid: email, email:)
        allow(User).to receive(:find_by).and_return(nil, linked_user, winner)
        allow(linked_user).to receive(:update!).and_raise(ActiveRecord::RecordNotUnique)

        expect(described_class.new(provider: 'google', uid:, email:, name: '山田 太郎').call).to eq(winner)
      end

      it '勝者を引き直せない場合は例外をそのまま投げる' do
        allow(User).to receive(:find_by).and_return(nil)
        allow(User).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

        expect do
          described_class.new(provider: 'google', uid:, email:, name: '山田 太郎').call
        end.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    context '同一ユーザーのサインインが実際に同時実行されたとき' do
      # 別スレッドの実コネクションから同じ email 行を奪い合わせるため、テスト用トランザクションを外す。
      self.use_transactional_tests = false

      after { ActiveRecord::Base.connection.execute('TRUNCATE TABLE users CASCADE') }

      # 同じ provider / uid / email の解決を同じタイミングで走らせ、発生した例外を集めて返す。
      def resolve_concurrently(count, uid:, email:)
        errors = Queue.new
        ready = Queue.new
        start = Queue.new
        threads = Array.new(count) do
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              ready << true
              start.pop
              described_class.new(provider: 'google', uid:, email:, name: '山田 太郎').call
            rescue StandardError => e
              errors << e
            end
          end
        end
        count.times { ready.pop }
        count.times { start << true }
        threads.each(&:join)
        Array.new(errors.size) { errors.pop }
      end

      it '一意制約の競合から復旧し、ユーザーを1件だけ作って全リクエストが成功する' do
        errors = resolve_concurrently(4, uid:, email:)

        aggregate_failures do
          # 失敗時に原因を追えるよう、件数ではなく例外の内容を突き合わせる。
          expect(errors.map { |e| "#{e.class}: #{e.message}" }).to be_empty
          expect(User.where(email:).count).to eq(1)
        end
      end
    end
  end
end
