module Neo4j::Driver
  module Internal
    class InternalResult
      include Enumerable

      def initialize(connection, cursor)
        @connection = connection
        @cursor = cursor
      end

      def keys
        @keys ||=
          begin
            blocking_get(@cursor.peek_async)
            @cursor.keys.map(&:to_sym)
          end
      end

      def has_next?
        blocking_get(@cursor.peek_async)
      end

      def next
        blocking_get(@cursor.next_async) or raise Exceptions::NoSuchRecordException.no_more
      end

      def single
        blocking_get(@cursor.single_async)
      end

      def peek
        blocking_get(@cursor.peek_async) or raise Exceptions::NoSuchRecordException.no_peek_past
      end

      def each
        yield self.next while has_next?
      end

      def consume
        blocking_get(@cursor.consume_async)
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
