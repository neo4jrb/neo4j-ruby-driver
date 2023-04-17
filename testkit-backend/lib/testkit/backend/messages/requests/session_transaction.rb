module Testkit::Backend::Messages
  module Requests
    class SessionTransaction < Request
      def process
        fetch(session_id).send(method, metadata: decode(tx_meta), timeout: timeout_duration) do |tx|
          tx_id = store(tx)
          @command_processor.process_response(named_entity('RetryableTry', id: tx_id))
          until @command_processor.process(blocking: true).is_a?(Retryable) do
          end
        ensure
          delete(tx_id)
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