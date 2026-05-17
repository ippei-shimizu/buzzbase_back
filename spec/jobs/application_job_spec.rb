require 'rails_helper'

RSpec.describe ApplicationJob, type: :job do
  describe 'class structure' do
    it 'is a subclass of ActiveJob::Base' do
      expect(described_class.superclass).to eq(ActiveJob::Base)
    end

    it 'defines a rescue handler for StandardError' do
      handler = described_class.rescue_handlers.find { |klass, _| klass == 'StandardError' }
      expect(handler).to be_present
    end
  end
end
