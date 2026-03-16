module Testkit
  module Backend
    class ReactiveTransactionContextStreamsAdapter
      def initialize(delegate)
        @delegate = delegate
      end

      def run(query, parameters = {})
        parameters.present? ? @delegate.run(query, parameters) : @delegate.run(query)
      end

      def commit
        raise java.lang.UnsupportedOperationException, "commit is not allowed on transaction context"
      end

      def roll_back
        raise java.lang.UnsupportedOperationException, "roll_back is not allowed on transaction context"
      end

      def close
        raise java.lang.UnsupportedOperationException, "close is not allowed on transaction context"
      end

      def open?
        raise java.lang.UnsupportedOperationException, "open? is not allowed on transaction context"
      end
    end
  end
end
