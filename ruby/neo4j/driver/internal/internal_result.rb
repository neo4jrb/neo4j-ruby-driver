module Neo4j::Driver
  module Internal
    class InternalResult
      extend Synchronizable
      include Enumerable
      sync :keys, :has_next?, :next, :single, :peek, :consume

      def initialize(connection, cursor)
        @connection = connection
        @cursor = cursor
      end

      def keys
        @keys ||=
          begin
            @cursor.peek_async
            @cursor.keys
          end
      end

      def has_next?
        @cursor.peek_async
      end

      def next
        @cursor.next_async || raise(Exceptions::NoSuchRecordException.no_more)
      end

      def single
        @cursor.single_async
      end

      def peek
        @cursor.peek_async or raise Exceptions::NoSuchRecordException.no_peek_past
      end

      def each
        yield self.next while has_next?
      end

      def consume
        @cursor.consume_async
      end

      def remove
        raise ClientException, 'Removing records from a result is not supported.'
      end

      private

      def blocking_get(stage)
        Util::Futures.blocking_get(stage, &method(:terminate_connection_on_thread_interrupt))
      end

      def terminate_connection_on_thread_interrupt
        @connection.terminate_and_release('Thread interrupted while waiting for result to arrive')
      end
    end
  end
end
