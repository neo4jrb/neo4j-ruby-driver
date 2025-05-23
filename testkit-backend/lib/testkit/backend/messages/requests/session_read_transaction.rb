module Testkit::Backend::Messages
  module Requests
    class SessionReadTransaction < SessionTransaction
      def process
        super(:execute_read)
      end
    end
  end
end