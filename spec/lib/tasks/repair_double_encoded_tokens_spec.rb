require 'rails_helper'
require 'rake'

RSpec.describe 'data:repair_double_encoded_tokens' do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:task) { Rake::Task['data:repair_double_encoded_tokens'] }

  before { task.reenable }

  context 'when a user has a double-encoded tokens value' do
    let!(:user) do
      u = create(:user)
      raw_json = '{"client_a":{"token":"hash","expiry":1234567890}}'
      # 実障害と同形 (json カラムに JSON 文字列を文字列としてラップした状態) を生 SQL で再現
      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql_array(
          ['UPDATE users SET tokens = ?::json WHERE id = ?', raw_json.to_json, u.id]
        )
      )
      u
    end

    it 'rewrites tokens as a plain Hash' do
      task.invoke
      user.reload
      expect(user.tokens).to eq('client_a' => { 'token' => 'hash', 'expiry' => 1_234_567_890 })
    end

    context 'when DRY_RUN=1' do
      around do |example|
        ENV['DRY_RUN'] = '1'
        example.run
      ensure
        ENV.delete('DRY_RUN')
      end

      it 'does not modify the underlying row' do
        task.invoke
        expect(user.reload.tokens).to be_a(String)
      end
    end
  end

  context 'when a user already has a healthy tokens hash' do
    let!(:user) do
      create(:user).tap do |u|
        u.update_columns(tokens: { 'client_a' => { 'token' => 'hash', 'expiry' => 1_234_567_890 } }) # rubocop:disable Rails/SkipsModelValidations
      end
    end

    it 'leaves the row untouched' do
      expect { task.invoke }.not_to(change { user.reload.tokens })
    end
  end
end
