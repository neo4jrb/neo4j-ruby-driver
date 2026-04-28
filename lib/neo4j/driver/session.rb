# frozen_string_literal: true

module Neo4j
  module Driver
    # Represents a session for executing queries
    class Session

      def initialize(driver, options = {})
        @driver = driver
        @options = options
        @connection = nil
        @transaction = nil
        @open = true
        @last_bookmarks = Set.new
        @current_result = nil

        # Initialize with provided bookmarks if any
        if options[:bookmarks]
          initial_bookmarks = options[:bookmarks]
          initial_bookmarks = [initial_bookmarks] unless initial_bookmarks.is_a?(Enumerable)
          initial_bookmarks.each do |bookmark|
            @last_bookmarks << (bookmark.is_a?(Bookmark) ? bookmark : Bookmark.new(bookmark))
          end
        end
      end

      def run(query, parameters = {}, config = {})
        parameters ||= {}

        unless parameters.is_a?(Hash)
          raise ArgumentError,
                "The parameters should be provided as Map type. Unsupported parameters type: #{parameters.class}"
        end

        raise Exceptions::ClientException, 'Session is closed' unless @open
        raise Exceptions::ClientException, 'You cannot run a query directly on a session while a transaction is open' if @transaction&.open?

        ensure_connection

        drain_current_result

        # Extract config options from **options
        timeout = config.delete(:timeout)
        tx_metadata = config.delete(:metadata)

        # For auto-commit transactions, use RUN + PULL
        run_extra = {
          db: @options[:database],
          tx_timeout: timeout_to_milliseconds(timeout),
          tx_metadata:
        }.compact

        @connection.send_message(Bolt::Message.run(query, parameters, run_extra))
        @connection.send_message(Bolt::Message.pull)
        @connection.flush

        # Get RUN response
        run_response = @connection.fetch_response

        unless run_response.is_a?(Bolt::Message::Success)
          handle_response_error(run_response)
        end

        keys = (run_response.metadata[:fields] || run_response.metadata['fields'] || []).map(&:to_sym)
        @current_result = Result.new(@connection, keys, query_text: query, parameters: parameters, run_metadata: run_response.metadata)
      end

      def begin_transaction(timeout: nil, metadata: nil, &block)
        raise Exceptions::ClientException, 'Session is closed' unless @open
        if @transaction&.open?
          raise Exceptions::ClientException,
                "You cannot begin a transaction on a session with an open transaction; either run from within the transaction or use a different session."
        end

        ensure_connection

        drain_current_result
        @current_result = nil

        tx_options = @options.merge(
          timeout: timeout_to_milliseconds(timeout),
          metadata: metadata
        ).compact

        @transaction = Transaction.new(@connection, self, @last_bookmarks.to_a, tx_options)

        if block_given?
          begin
            result = yield @transaction
            # Explicit-block transactions default to rollback; user must call
            # tx.commit to persist changes (matches Java driver semantics).
            @transaction.rollback if @transaction.open?
            result
          rescue => e
            @transaction.rollback if @transaction.open?
            raise e
          ensure
            @transaction = nil
          end
        else
          @transaction
        end
      end

      def execute_read(timeout: nil, metadata: nil, &block)
        execute_transaction(AccessMode::READ, timeout: timeout, metadata: metadata, &block)
      end

      def execute_write(timeout: nil, metadata: nil, &block)
        execute_transaction(AccessMode::WRITE, timeout: timeout, metadata: metadata, &block)
      end

      def close
        return unless @open

        pending_error = nil
        begin
          @transaction&.close
          if @current_result
            begin
              @current_result.buffer
            rescue Exceptions::Neo4jException => e
              pending_error = e
            end
            # Any failure during the last result leaves the connection in
            # the server's FAILED state; RESET so the next borrower starts
            # from a clean READY state.
            @connection.reset! if @connection && @current_result.failed?
            @current_result.discard!
          end
        ensure
          @driver.release_connection(@connection) if @connection
          @connection = nil
          @open = false
        end

        raise pending_error if pending_error
      end

      def open?
        @open
      end

      def last_bookmarks
        @last_bookmarks
      end

      def update_bookmarks(bookmarks)
        # Replace bookmarks (don't accumulate) - matches Java driver behavior
        # Each committed transaction generates a new bookmark that replaces the previous one
        @last_bookmarks = Set.new(Array(bookmarks).map(&Bookmark.method(:new)))
      end

      private

      def ensure_connection
        @connection ||= @driver.acquire_connection
      end

      # Pull any pending auto-commit result's records into memory so records
      # remain accessible from the user's reference after the connection is
      # reused for a new RUN or BEGIN. If draining surfaces a failure — either
      # directly from #buffer or from a prior #consume the user caught — RESET
      # the server so the next query lands cleanly, and re-raise direct
      # failures so callers see the real cause.
      def drain_current_result
        return unless @current_result

        begin
          @current_result.buffer
        rescue Exceptions::Neo4jException
          @connection.reset!
          raise
        end

        @connection.reset! if @current_result.failed?
      end

      # Convert timeout from seconds (or ActiveSupport::Duration) to milliseconds for Bolt protocol
      def timeout_to_milliseconds(timeout) = timeout&.then { (it.to_f * 1000).round }

      def execute_transaction(access_mode, timeout: nil, metadata: nil, &block)
        raise Exceptions::ClientException, 'Session is closed' unless @open

        max_retry_time = @options[:max_transaction_retry_time] || 2
        start_time = Time.now
        errors = []

        loop do
          begin
            tx_options = @options.merge(
              access_mode: access_mode == AccessMode::READ ? 'r' : 'w',
              timeout: timeout_to_milliseconds(timeout),
              metadata:
            ).compact
            return begin_transaction_internal(tx_options, &block)
          rescue Exceptions::ServiceUnavailableException, Exceptions::TransientException => e
            errors << e

            # Check if we should retry
            if Time.now - start_time >= max_retry_time
              raise Exceptions::ServiceUnavailableException.new(
                "Transaction failed after retries: #{e.message}",
                code: e.code,
                suppressed: errors[0...-1]
              )
            end

            # Exponential backoff: 1s, 2s, 4s, ... matching Java driver defaults
            sleep(2 ** (errors.size - 1))

            # Release connection so the retry acquires a fresh one
            @driver.release_connection(@connection) if @connection
            @connection = nil
          end
        end
      end

      def begin_transaction_internal(options, &block)
        raise Exceptions::ClientException, 'Session is closed' unless @open
        if @transaction&.open?
          raise Exceptions::ClientException,
                "You cannot begin a transaction on a session with an open transaction"
        end

        ensure_connection

        @transaction = Transaction.new(@connection, self, @last_bookmarks.to_a, options)

        begin
          result = yield @transaction
          @transaction.commit unless @transaction.instance_variable_get(:@committed) || !@transaction.open?
          result
        rescue => e
          @transaction.rollback if @transaction.open?
          raise e
        ensure
          @transaction = nil
        end
      end

      def handle_response_error(response)
        if response.is_a?(Bolt::Message::Failure)
          code = response.code
          message = response.message

          exception_class = case code
                            when /^Neo\.ClientError\.Security\.Unauthorized/
                              Exceptions::AuthenticationException
                            when /^Neo\.ClientError\.Security/
                              Exceptions::SecurityException
                            when /^Neo\.ClientError/
                              Exceptions::ClientException
                            when /^Neo\.TransientError/
                              Exceptions::TransientException
                            else
                              Exceptions::DatabaseException
                            end

          # Server is in FAILED state and any queued messages (e.g. the PULL
          # that followed our RUN) will be IGNORED. Drain them and RESET so
          # the session is immediately usable for the next query.
          @connection.reset!
          raise exception_class.new(message, code: code)
        elsif response.is_a?(Bolt::Message::Ignored)
          @connection.reset!
          raise Exceptions::ClientException, "Request was ignored by server (likely due to previous error)"
        else
          raise Exceptions::ClientException, "Unexpected response: #{response.class}"
        end
      end
    end
  end
end
