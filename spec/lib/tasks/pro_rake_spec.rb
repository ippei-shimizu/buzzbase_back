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
end
