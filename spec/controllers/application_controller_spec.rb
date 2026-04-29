require 'rails_helper'

# Bug #246 (BUZZBASE-BACKEND-G) のリグレッション検証
# update_last_login_at が new_record? の current_user で呼ばれても落ちないことを担保する
RSpec.describe ApplicationController, type: :controller do
  controller(described_class) do
    def index
      head :ok
    end
  end

  describe '#update_last_login_at (after_action)' do
    let(:controller_instance) { controller }

    context 'when current_user is nil' do
      before { allow(controller_instance).to receive(:current_user).and_return(nil) }

      it 'returns early without raising' do
        expect { controller_instance.send(:update_last_login_at) }.not_to raise_error
      end
    end

    context 'when current_user is a new (unsaved) record' do
      before { allow(controller_instance).to receive(:current_user).and_return(User.new(email: 'unsaved@example.com')) }

      it 'returns early without raising ActiveRecord::ActiveRecordError' do
        expect { controller_instance.send(:update_last_login_at) }.not_to raise_error
      end

      it 'does not attempt update_column on the unsaved record' do
        allow(controller_instance.current_user).to receive(:update_column)
        controller_instance.send(:update_last_login_at)
        expect(controller_instance.current_user).not_to have_received(:update_column)
      end
    end

    context 'when current_user is persisted with a recent last_login_at' do
      let(:user) { create(:user, last_login_at: 30.minutes.ago) }

      before { allow(controller_instance).to receive(:current_user).and_return(user) }

      it 'does not update last_login_at again' do
        expect { controller_instance.send(:update_last_login_at) }
          .not_to(change { user.reload.last_login_at })
      end
    end

    context 'when current_user is persisted with an old last_login_at' do
      let(:user) { create(:user, last_login_at: 2.hours.ago) }

      before { allow(controller_instance).to receive(:current_user).and_return(user) }

      it 'updates last_login_at to the current time' do
        expect { controller_instance.send(:update_last_login_at) }
          .to(change { user.reload.last_login_at })
      end
    end

    context 'when current_user is persisted with no last_login_at' do
      let(:user) { create(:user, last_login_at: nil) }

      before { allow(controller_instance).to receive(:current_user).and_return(user) }

      it 'sets last_login_at for the first time' do
        controller_instance.send(:update_last_login_at)
        expect(user.reload.last_login_at).to be_present
      end
    end
  end
end
