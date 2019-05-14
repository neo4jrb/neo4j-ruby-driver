# frozen_string_literal: true

module Neo4j
  module Driver
    class InternalSession
      include ErrorHandling
      include StatementRunner

      attr_reader :bookmarks, :requests

      def initialize(connector, mode, bookmarks)
        @connector = connector
        @mode = mode
        @bookmarks = bookmarks
        @requests = []
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
        process(true)
        close_transaction_and_release_connection
      end

      def release_connection
        return unless @connection
        Bolt::Connector.release(@connector, @connection)
        @connection = nil
      end

      def begin_transaction(mode = @mode, config = nil)
        # ensureNoOpenTxBeforeStartingTx
        acquire_connection(mode)
        @transaction = ExplicitTransaction.new(@connection, self).begin(config)
      end

      def bookmarks=(bookmarks)
        @bookmarks = Array(bookmarks) if bookmarks.present?
      end

      def last_bookmark
        @bookmarks.max
      end

      private

      def transaction(mode, config = nil)
        # retry logic should go here
        tx = begin_transaction(mode, config)
        result = yield tx
        tx.success
        result
      rescue StandardError => e
        tx&.failure
        raise e
      ensure
        close_transaction_and_release_connection
      end

      def acquire_connection(mode = @mode)
        raise Exception, 'existing connection present' if @connection

        status = Bolt::Status.create
        @connection = Bolt::Connector.acquire(@connector, mode, status)
        check_status(status)
      end

      def close_transaction_and_release_connection
        @transaction&.close
      ensure
        @transaction = nil
        release_connection
      end
    end
  end
end
