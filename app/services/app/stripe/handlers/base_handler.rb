module App
  module Stripe
    module Handlers
      # 全 event handler の共通基底。各サブクラスは `call` だけ実装する。
      class BaseHandler
        def initialize(payload)
          @payload = payload
        end

        def call
          raise NotImplementedError, "#{self.class.name} must implement #call"
        end

        protected

        attr_reader :payload
      end
    end
  end
end
