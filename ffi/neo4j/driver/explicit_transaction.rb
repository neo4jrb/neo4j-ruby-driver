# frozen_string_literal: true

require 'neo4j/driver/statement_runner'

module Neo4j
  module Driver
    class ExplicitTransaction
      include ErrorHandling
      include StatementRunner

      def initialize(connection, session)
        @connection = connection
        @session = session
        @state = :active
      end

      def begin(initial_bookmarks, config)
        check_error Bolt::Connection.clear_begin(@connection)
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

      def commit
        case @state
        when :committed
          nil
        when :rolled_back
          raise ClientExceptiom, "Can't commit, transaction has been rolled back"
        else
          do_commit
          # handleCommitOrRollback( error )
          transaction_closed(:committed)
        end
      end

      def do_commit
        if @state == :terminated
          raise ClientException, "Transaction can't be committed. " \
          'It has been rolled back either because of an error or explicit termination'
        end

        Bolt::Connection.load_commit_request(@connection)
        Bolt::Connection.send(@connection)
      end

      # return protocol.commitTransaction( connection )
      #          .thenApply( newBookmarks ->
      # {
      #   session.setBookmarks( newBookmarks );
      # return null;
      # } );
      # end
      #

      def rollback
        case @state
        when :committed
          raise ClientException, "Can't rollback, transaction has been committed"
        when :rolled_back
          nil
        else
          do_rollback
          # resultCursors.retrieveNotConsumedError()
          # handleCommitOrRollback( error )
          transaction_closed(:rolled_back)
        end
      end

      def do_rollback
        return if @state == :terminated

        Bolt::Connection.load_rollback_request(@connection)
        Bolt::Connection.send(@connection)
      end

      def transaction_closed(new_state)
        @state = new_state
        @session.release_connection
      end
    end
  end
end
