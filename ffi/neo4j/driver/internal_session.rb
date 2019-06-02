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
        puts "in InteernalSession#run"
        ensure_connection
        super(statement, parameters, :set_run_bookmarks)
      end

      def read_transaction(&block)
        transaction(Neo4j::Driver::AccessMode::READ, &block)
      end

      def write_transaction(&block)
        transaction(Neo4j::Driver::AccessMode::WRITE, &block)
      end

      def close
        puts "in InteernalSession#close"
        puts requests.inspect
        process(true) if @connection
        save_bookmark if @connection && @flushed
        close_transaction_and_release_connection
      end

      def release_connection
        return unless @connection
        puts "before release"
        Bolt::Connector.release(@connector, @connection)
        @connection = nil
      end

      def begin_transaction(mode = @mode, config = nil)
        # ensureNoOpenTxBeforeStartingTx
        acquire_connection(mode)
        @transaction = ExplicitTransaction.new(@connection, self).begin(config)
      end

      def save_bookmark
        puts 'in save_bookmark'
        puts requests.inspect
        process(true)
        puts @requests.inspect
        puts caller
        self.bookmarks = Bolt::Connection.last_bookmark(@connection).first
      end

      def bookmarks=(bookmarks)
        @bookmarks = Array(bookmarks) if bookmarks.present?
      end

      def last_bookmark
        save_bookmark
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

      def ensure_connection(mode = @mode)
        connection_present? || acquire_connection(mode)
      end

      def connection_present?
        save_bookmark if @connection
        @connection
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
