# frozen_string_literal: true

require 'set'

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

        raise Exceptions::ClientException, 'Session is closed' unless @open
        raise Exceptions::ClientException, 'You cannot run a query directly on a session while a transaction is open' if @transaction&.open?

        ensure_connection

        # Auto-consume any previous unconsumed result
        @current_result&.consume rescue nil

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

      def begin_transaction(&block)
        raise Exceptions::ClientException, 'Session is closed' unless @open
        if @transaction&.open?
          raise Exceptions::ClientException,
                "You cannot begin a transaction on a session with an open transaction; either run from within the transaction or use a different session."
        end

        ensure_connection

        @transaction = Transaction.new(@connection, self, @last_bookmarks.to_a, @options)

        if block_given?
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

        begin
          @transaction&.close
        ensure
          @connection&.close
          @connection = nil
          @open = false
        end
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

      # Convert timeout from seconds (or ActiveSupport::Duration) to milliseconds for Bolt protocol
      def timeout_to_milliseconds(timeout)
        return nil unless timeout
        timeout_seconds = timeout.respond_to?(:to_i) ? timeout.to_i : timeout
        (timeout_seconds * 1000).to_i
      end

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

            # Backoff before retry
            sleep(0.1 * [errors.size, 10].min)

            # Reset connection for retry
            @connection&.close
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

          raise exception_class.new(message, code: code)
        elsif response.is_a?(Bolt::Message::Ignored)
          # IGNORED means previous request failed, we need to send RESET
          @connection.send_message(Bolt::Message.reset)
          @connection.flush
          @connection.fetch_response # Get RESET response
          raise Exceptions::ClientException, "Request was ignored by server (likely due to previous error)"
        else
          raise Exceptions::ClientException, "Unexpected response: #{response.class}"
        end
      end
    end
  end
end
