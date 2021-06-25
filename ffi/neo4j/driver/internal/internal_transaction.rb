# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class InternalTransaction
        include ErrorHandling

        delegate :finalize, to: :@handler

        def initialize(connection, session)
          @connection = connection
          @protocol = connection.protocol
          @session = session
          @state = :active
        end

        def begin(initial_bookmarks, config)
          chain @protocol.begin_transaction(@connection, initial_bookmarks, config)
          finalize if initial_bookmarks.present?
          self
        rescue StandardError => e
          @connection.release
          raise e
        end

        def run(query, parameters = {})
          ensure_can_run_queries
          @result&.failure
          @result = @protocol.run_in_explicit_transaction(@connection, Query.new(query, parameters), self)
        end

        def commit
          case @state
          when :committed
            raise Exceptions::ClientException, "Can't commit, transaction has been committed"
          when :rolled_back
            raise Exceptions::ClientException, "Can't commit, transaction has been rolled back"
          when :active
            begin
              do_commit
                # handleCommitOrRollback( error )
            ensure
              transaction_closed(:committed)
            end
          else
            nil
          end
        end

        def rollback
          case @state
          when :committed
            raise Exceptions::ClientException, "Can't rollback, transaction has been committed"
          when :rolled_back
            raise Exceptions::ClientException, "Can't rollback, transaction has been rolled back"
          when :active
            begin
              do_rollback
                # resultCursors.retrieveNotConsumedError()
                # handleCommitOrRollback( error )
            ensure
              transaction_closed(:rolled_back)
            end
          else
            nil
          end
        end

        def mark_terminated
          @state = :terminated
        end

        def close
          rollback if open?
        ensure
          transaction_closed(:rolled_back)
        end

        def open?
          %i[active terminated].include? @state
        end

        def chain(*handlers)
          handlers.each do |handler|
            handler.previous = @handler
            @handler = handler
          end
        end

        private

        def do_commit
          # @session.bookmarks = @protocol.commit_transaction(@connection)
          chain @protocol.commit_transaction(@connection)
          finalize
          @session.bookmarks = @connection.last_bookmark
        end

        def do_rollback
          chain @protocol.rollback_transaction(@connection)
          finalize
        end

        def transaction_closed(new_state)
          @state = new_state unless @state == :committed
          @session.release_connection
        end

        def ensure_can_run_queries
          reason =
            case @state
            when :committed
              'Cannot run more queries in this transaction, it has been committed'
            when :rolled_back
              'Cannot run more queries in this transaction, it has been rolled back'
            when :terminated
              'Cannot run more queries in this transaction, ' \
            'it has either experienced an fatal error or was explicitly terminated'
            end

          raise Exceptions::ClientException, reason if reason
        end
      end
    end
  end
end
