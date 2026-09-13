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

  describe 'pro:mark_internal' do
    let(:task) { Rake::Task['pro:mark_internal'] }

    before { task.reenable }

    it '対象ユーザーの subscription に internal_grant と理由を設定する' do
      subscription = create(:subscription, :active)

      expect { task.invoke(subscription.user_id.to_s, '録画用') }.to output(/internal_grant を設定しました/).to_stdout

      expect(subscription.reload.internal_grant).to be true
      expect(subscription.internal_grant_reason).to eq '録画用'
    end

    it 'reason が無ければ何も更新せずエラーにする' do
      subscription = create(:subscription, :active)

      expect { task.invoke(subscription.user_id.to_s) }.to raise_error(ArgumentError)
      expect(subscription.reload.internal_grant).to be false
    end
  end

  describe 'pro:unmark_internal' do
    let(:task) { Rake::Task['pro:unmark_internal'] }

    before { task.reenable }

    it 'internal_grant を解除する' do
      subscription = create(:subscription, :internal_grant)

      expect { task.invoke(subscription.user_id.to_s) }.to output(/internal_grant を解除しました/).to_stdout

      expect(subscription.reload.internal_grant).to be false
      expect(subscription.internal_grant_reason).to be_nil
    end
  end

  describe 'pro:revoke_internal_grant' do
    let(:task) { Rake::Task['pro:revoke_internal_grant'] }

    before { task.reenable }

    it '手動付与を free に戻す' do
      subscription = create(:subscription, :internal_grant)

      expect { task.invoke(subscription.user_id.to_s) }.to output(/手動付与を無効化しました/).to_stdout

      expect(subscription.reload.status).to eq 'free'
    end

    it '実課金のレコードは変更しない' do
      subscription = create(:subscription, :active)

      expect { task.invoke(subscription.user_id.to_s) }.to raise_error(Subscription::NotInternalGrant)
      expect(subscription.reload.status).to eq 'active'
    end
  end

  describe 'pro:audit' do
    let(:task) { Rake::Task['pro:audit'] }

    before { task.reenable }

    it '実課金と内部付与を分けて出力する' do
      create(:subscription, :active)
      create(:subscription, :internal_grant)
      create(:subscription, :free)

      expect { task.invoke }.to output(/実課金（分析対象）: 1 件.*内部付与（分析から除外）: 1 件/m).to_stdout
    end

    it 'フラグ漏れの疑いがあるレコードを警告する' do
      create(:subscription, :active, started_at: nil)

      expect { task.invoke }.to output(/要確認: started_at が null/).to_stdout
    end
  end
end
