# frozen_string_literal: true

module Neo4j
  module Driver
    # Represents the result of running a Cypher statement
    class Result
      include Enumerable

      def initialize(connection, keys = [], query_text: nil, parameters: {}, run_metadata: {})
        @connection = connection
        @keys = keys
        @query_text = query_text
        @parameters = parameters
        @run_metadata = run_metadata
        @records = []       # records pulled into memory by #buffer (not by iteration)
        @summary = nil
        @consumed = false   # stream has been fully drained from the wire
        @discarded = false  # records were explicitly released; further access raises
        @peeked_record = nil
      end

      def keys
        @keys
      end

      def has_next?
        return true if @records.any?
        return false if @consumed
        return true if @peeked_record

        response = @connection.fetch_response

        case response
        when Bolt::Message::Record
          @peeked_record = Record.new(@keys, response.fields)
          true
        when Bolt::Message::Success
          @summary = Summary.new(@run_metadata.merge(response.metadata), @query_text, @parameters, @connection)
          @consumed = true
          false
        when Bolt::Message::Failure
          @summary = Summary.new(@run_metadata.merge(response.metadata), @query_text, @parameters, @connection)
          @consumed = true
          handle_failure(response)
        else
          false
        end
      rescue StandardError
        @consumed = true
        raise
      end

      def next
        raise Exceptions::ResultConsumedException if @discarded
        return @records.shift if @records.any?
        raise Exceptions::NoSuchRecordException, 'No more records' unless has_next?

        record = @peeked_record
        @peeked_record = nil
        record
      end

      def peek
        raise Exceptions::ResultConsumedException if @discarded
        return @records.first if @records.any?
        raise Exceptions::NoSuchRecordException, 'No more records' unless has_next?

        @peeked_record
      end

      def single
        raise Exceptions::ResultConsumedException if @discarded

        unless has_next?
          raise Exceptions::NoSuchRecordException,
                'Cannot retrieve a single record, because this result is empty.'
        end

        record = self.next

        if has_next?
          raise Exceptions::NoSuchRecordException,
                'Expected a result with a single record, but this result contains at least one more. ' \
                'Ensure your query returns only one record.'
        end

        record
      end

      def each(&block)
        raise Exceptions::ResultConsumedException if @discarded
        return to_enum(:each) unless block_given?

        block.call(self.next) while has_next?
      end

      def to_a
        raise Exceptions::ResultConsumedException if @discarded

        records = []
        records << self.next while has_next?
        records
      end

      def consume
        return @summary if @discarded

        @peeked_record = nil

        begin
          until @consumed
            response = @connection.fetch_response
            case response
            when Bolt::Message::Record
              # discard silently
            when Bolt::Message::Success
              @summary = Summary.new(@run_metadata.merge(response.metadata), @query_text, @parameters, @connection)
              @consumed = true
            when Bolt::Message::Failure
              @summary = Summary.new(@run_metadata.merge(response.metadata), @query_text, @parameters, @connection)
              @consumed = true
              handle_failure(response)
            else
              break
            end
          end
        ensure
          @records.clear
          @discarded = true
        end

        @summary
      end

      # Pull all remaining records into memory so the underlying connection
      # can be reused for another query. Unlike #consume, records stay
      # accessible via #each/#to_a/etc.
      def buffer
        return if @consumed

        if @peeked_record
          @records << @peeked_record
          @peeked_record = nil
        end

        until @consumed
          response = @connection.fetch_response
          case response
          when Bolt::Message::Record
            @records << Record.new(@keys, response.fields)
          when Bolt::Message::Success
            @summary = Summary.new(@run_metadata.merge(response.metadata), @query_text, @parameters, @connection)
            @consumed = true
          when Bolt::Message::Failure
            @summary = Summary.new(@run_metadata.merge(response.metadata), @query_text, @parameters, @connection)
            @consumed = true
            handle_failure(response)
          else
            break
          end
        end
      end

      def none?
        !has_next?
      end

      # Mark this result as released without touching the wire. Used by the
      # session when closing — the underlying connection is gone, so further
      # record access is impossible and must raise ResultConsumedException.
      def discard!
        @peeked_record = nil
        @discarded = true
      end

      private

      def handle_failure(failure)
        code = failure.code
        message = failure.message

        exception_class = case code
                          when /^Neo\.ClientError\.Security/
                            Exceptions::SecurityException
                          when /^Neo\.ClientError/
                            Exceptions::ClientException
                          when /^Neo\.TransientError/
                            Exceptions::TransientException
                          when /^Neo\.DatabaseError/
                            Exceptions::DatabaseException
                          else
                            Exceptions::Neo4jException
                          end

        raise exception_class.new(message, code: code)
      end
    end
  end
end
