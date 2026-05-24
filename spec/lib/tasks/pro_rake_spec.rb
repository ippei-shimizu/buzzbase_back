require 'rails_helper'
require 'rake'

RSpec.describe 'pro:* rake tasks' do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?('pro:trial_expiring_reminder')
  end

  describe 'pro:trial_expiring_reminder' do
    let(:task) { Rake::Task['pro:trial_expiring_reminder'] }

    before { task.reenable }

    it 'TrialExpiringReminderJob#perform を呼び出す' do
      job_instance = instance_double(TrialExpiringReminderJob, perform: nil)
      allow(TrialExpiringReminderJob).to receive(:new).and_return(job_instance)

      task.invoke
      expect(job_instance).to have_received(:perform)
    end
  end

  describe 'pro:pro_expiring_reminder' do
    let(:task) { Rake::Task['pro:pro_expiring_reminder'] }

    before { task.reenable }

    it 'ProExpiringReminderJob#perform を呼び出す' do
      job_instance = instance_double(ProExpiringReminderJob, perform: nil)
      allow(ProExpiringReminderJob).to receive(:new).and_return(job_instance)

      task.invoke
      expect(job_instance).to have_received(:perform)
    end
  end
end
