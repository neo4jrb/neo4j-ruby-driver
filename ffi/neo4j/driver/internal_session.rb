# frozen_string_literal: true

module Neo4j
  module Driver
    class InternalSession
      include ErrorHandling
      include StatementRunner

      def initialize(connector, mode)
        @connector = connector
        @mode = mode
        @bookmarks = []
        # @transaction = nil
      end

      def run(statement, parameters = {})
        acquire_connection
        super
      end

      def read_transaction(&block)
        transaction(Neo4j::Driver::AccessMode::READ, &block)
      end

      def write_transaction(&block)
        transaction(Neo4j::Driver::AccessMode::WRITE, &block)
      end

      def close
        close_transaction_and_release_connection
      end

      def release_connection
        Bolt::Connector.release(@connector, @connection) if @connection
        @connection = nil
      end

      def begin_transaction(mode = @mode, config = nil)
        # ensureNoOpenTxBeforeStartingTx
        acquire_connection(mode)
        @transaction = ExplicitTransaction.new(@connection, self).begin(@bookmarks, config)
      end

      private

      def transaction(mode, config = nil)
        # retry logic should go here
        tx = begin_transaction(mode, config)
        result = yield tx
        tx.success
        result
      rescue e
        tx&.failure
        raise e
      ensure
        tx&.close
      end

      def acquire_connection(mode = @mode)
        raise Exception, 'existing connection present' if @connection

        status = Bolt::Status.create
        @connection = Bolt::Connector.acquire(@connector, mode, status)
        raise Exception, check_and_print_error(nil, status, 'unable to acquire connection') if @connection.null?
      end

      def close_transaction_and_release_connection
        @transaction&.close
        release_connection
      end
    end
  end
end
