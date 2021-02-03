module Testkit::Backend::Messages
  module Requests
    class SessionTransaction < Request

      def process
        fetch(sessionId).send(method, metadata: txMeta, timeout: timeout_duration) do |tx|
          @command_processor.process_response(named_entity('RetryableTry', id: store(tx)))
          until @command_processor.process(blocking: true).is_a?(Retryable) do
          end
          delete(tx.object_id) # TODO: remove in negative case too
        end
        named_entity('RetryableDone')
      end

      private

      def method
        self.class.name.gsub(/.*Session/, '').underscore
      end
    end
  end
end