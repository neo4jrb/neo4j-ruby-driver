module Neo4j::Driver
  module Internal
    class InternalResult
      include Enumerable
      delegate :keys, to: :@cursor

      def initialize(connection, cursor)
        @connection = connection
        @cursor = cursor
      end

      def has_next?
        @cursor.peek_async.result!
      end

      def next
        @cursor.next_async.result! || raise(Exceptions::NoSuchRecordException.no_more)
      end

      def single
        @cursor.single_async.result!
      end

      def peek
        @cursor.peek_async.result! or raise Exceptions::NoSuchRecordException.no_peek_past
      end

      def each
        yield self.next while has_next?
      end

      def consume
        @cursor.consume_async.result!
      end

      def remove
        raise ClientException, 'Removing records from a result is not supported.'
      end

      private

      def terminate_connection_on_thread_interrupt
        @connection.terminate_and_release('Thread interrupted while waiting for result to arrive')
      end
    end
  end
end
