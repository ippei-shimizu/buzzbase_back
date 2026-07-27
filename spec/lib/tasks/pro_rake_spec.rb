require 'rails_helper'
require 'rake'

# rake task は class でも module でもないため文字列で describe する（.rubocop.yml で除外設定済み）。
RSpec.describe 'pro:* rake tasks' do
  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?('pro:trial_expiring_reminder')
  end

  describe 'pro:trial_expiring_reminder' do
    let(:task) { Rake::Task['pro:trial_expiring_reminder'] }

    before { task.reenable }

    it 'TrialExpiringReminderJob.perform_now を呼び出す' do
      allow(TrialExpiringReminderJob).to receive(:perform_now)
      task.invoke
      expect(TrialExpiringReminderJob).to have_received(:perform_now)
    end
  end

  describe 'pro:pro_expiring_reminder' do
    let(:task) { Rake::Task['pro:pro_expiring_reminder'] }

    before { task.reenable }

    it 'ProExpiringReminderJob.perform_now を呼び出す' do
      allow(ProExpiringReminderJob).to receive(:perform_now)
      task.invoke
      expect(ProExpiringReminderJob).to have_received(:perform_now)
    end
  end

  describe 'pro:make_admin' do
    let(:task) { Rake::Task['pro:make_admin'] }
    let(:user) { create(:user, is_admin: false) }

    before { task.reenable }

    it '指定したメールアドレスのユーザーを is_admin: true にする' do
      task.invoke(user.email)
      expect(user.reload.is_admin).to be true
    end

    it 'email が空のときは例外を送出する' do
      expect { task.invoke }.to raise_error(/Usage/)
    end

    it '存在しないメールアドレスのときは例外を送出する' do
      expect { task.invoke('unknown@example.com') }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'production 環境では例外を送出する' do
      allow(Rails.env).to receive(:production?).and_return(true)
      expect { task.invoke(user.email) }.to raise_error('production では実行できません')
    end
  end
end
