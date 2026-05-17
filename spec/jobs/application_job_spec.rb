require 'rails_helper'

# sentry-rails の ActiveJob 連携がテスト環境で current_hub 未初期化のため、
# perform_now 経由の振る舞いテストは不可。構造検証に絞る。
RSpec.describe ApplicationJob, type: :job do
  describe 'class structure' do
    it 'inherits from ActiveJob::Base' do
      expect(described_class.ancestors).to include(ActiveJob::Base)
    end

    # rescue_handlers は内部 API だが、rescue_from の登録結果を観測する他の手段がない。
    it 'registers a rescue handler for StandardError via rescue_from' do
      handler = described_class.rescue_handlers.find { |klass, _| klass == 'StandardError' }
      expect(handler).to be_present
    end
  end
end
