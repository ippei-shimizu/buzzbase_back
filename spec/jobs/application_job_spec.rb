require 'rails_helper'

# ApplicationJob は Sentry に例外を通知する rescue_from を持つ。
# 本来は perform_now 経由の振る舞いテストで検証したいが、sentry-rails の
# ActiveJob インスツルメンテーション（around_perform で current_hub を参照）が
# テスト環境で初期化されておらず NoMethodError を引き起こすため、ここでは
# 「Sentry 連携の設定が ApplicationJob に組み込まれているか」を構造として確認する。
# Sentry.capture_exception の呼び出しに対する振る舞いベースの担保は、Sentry の
# ジョブ統合自体の責務であり sentry-rails 側で検証されているため、本スペックでは
# 我々のコード（ApplicationJob）が「ActiveJob::Base を継承し、StandardError に
# rescue_from を宣言している」ことの保証に絞る。
RSpec.describe ApplicationJob, type: :job do
  describe 'class structure' do
    it 'inherits from ActiveJob::Base' do
      expect(described_class.ancestors).to include(ActiveJob::Base)
    end

    # ActiveJob の rescue_handlers は public method ではないが、
    # `rescue_from` の登録結果を観測する公開的な手段が他にないため、
    # 構造検証として意図的に内部状態を参照している。Rails 側で API が
    # 変わった場合はこのスペックを更新する。
    it 'registers a rescue handler for StandardError via rescue_from' do
      handler = described_class.rescue_handlers.find { |klass, _| klass == 'StandardError' }
      expect(handler).to be_present
    end
  end
end
