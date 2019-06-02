# frozen_string_literal: true

require 'neo4j/driver/statement_runner'

module Neo4j
  module Driver
    class ExplicitTransaction
      include ErrorHandling
      include StatementRunner
      include Internal::Protocol

      delegate :bookmarks, :requests, to: :@session

      def initialize(connection, session)
        @connection = connection
        @session = session
        @state = :active
      end

      def begin(config)
        check_error Bolt::Connection.clear_begin(@connection)
        set_bookmarks if bookmarks.present?
        request Bolt::Connection.load_begin_request(@connection)
        process(true) if bookmarks.present?
        self
      end

      def success
        @state = :marked_success if @state == :active
      end

      def failure
        @state = :marked_failed if %i[active marked_success].include? @state
      end

      def close
        case @state
        when :marked_success
          commit
        when :committed, :rolled_back
          nil
        else
          rollback
        end
      end

      private

      def set_bookmarks
        value = Bolt::Value.create
        Neo4j::Driver::Value.to_neo(value, bookmarks)
        check_error Bolt::Connection.set_begin_bookmarks(@connection, value)
      end

      def commit
        case @state
        when :committed
          nil
        when :rolled_back
          raise ClientExceptiom, "Can't commit, transaction has been rolled back"
        else
          begin
            do_commit
            # handleCommitOrRollback( error )
          ensure
            transaction_closed(:committed)
          end
        end
      end

      def do_commit
        if @state == :terminated
          raise ClientException, "Transaction can't be committed. " \
          'It has been rolled back either because of an error or explicit termination'
        end

        request Bolt::Connection.load_commit_request(@connection)
        process(true)
        @session.bookmarks = Bolt::Connection.last_bookmark(@connection).first
      end

      def rollback
        case @state
        when :committed
          raise ClientException, "Can't rollback, transaction has been committed"
        when :rolled_back
          nil
        else
          begin
            do_rollback
            # resultCursors.retrieveNotConsumedError()
            # handleCommitOrRollback( error )
          ensure
            transaction_closed(:rolled_back)
          end
        end
      end

      def do_rollback
        return if @state == :terminated

        request Bolt::Connection.load_rollback_request(@connection)
        process(true)
      end

      def transaction_closed(new_state)
        @state = new_state
        @session.release_connection
      end
    end
  end
end
