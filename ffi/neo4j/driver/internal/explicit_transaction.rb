# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class ExplicitTransaction
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
          self
        rescue StandardError => e
          @connection.release
          raise e
        end

        def run(query, parameters = {})
          ensure_can_run_queries
          @protocol.run_in_explicit_transaction(@connection, Statement.new(query, parameters), self)
        end

        def success
          @state = :marked_success if @state == :active
        end

        def failure
          @state = :marked_failed if %i[active marked_success].include? @state
        end

        def mark_terminated
          @state = :terminated
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

        def open?
          !%i[committed rolled_back].include? @state
        end

        def chain(*handlers)
          handlers.each do |handler|
            handler.previous = @handler
            @handler = handler
          end
        end

        private

        def commit
          case @state
          when :committed
            nil
          when :rolled_back
            raise Exceptions::ClientExceptiom, "Can't commit, transaction has been rolled back"
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
            raise Exceptions::ClientException, "Transaction can't be committed. " \
          'It has been rolled back either because of an error or explicit termination'
          end

          # @session.bookmarks = @protocol.commit_transaction(@connection)
          chain @protocol.commit_transaction(@connection)
          finalize
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

          chain @protocol.rollback_transaction(@connection)
          finalize
        end

        def transaction_closed(new_state)
          @state = new_state
          @session.release_connection
        end

        def ensure_can_run_queries
          reason =
            case @state
            when :committed
              'Cannot run more statements in this transaction, it has been committed'
            when :rolled_back
              'Cannot run more statements in this transaction, it has been rolled back'
            when :marked_failed
              'Cannot run more statements in this transaction, it has been marked for failure. ' \
            'Please either rollback or close this transaction'
            when :terminated
              'Cannot run more statements in this transaction, ' \
            'it has either experienced an fatal error or was explicitly terminated'
            else
              nil
            end

          raise Exceptions::ClientException, reason if reason
        end
      end
    end
  end
end