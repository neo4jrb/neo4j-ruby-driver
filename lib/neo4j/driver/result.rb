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
        @run_metadata = run_metadata  # Metadata from RUN SUCCESS (contains t_first)
        @records = []
        @summary = nil
        @consumed = false
        @peeked_record = nil
      end

      def keys
        @keys
      end

      def has_next?
        return false if @consumed

        return true if @peeked_record

        # Try to fetch next record
        begin
          response = @connection.fetch_response
          case response
          when Bolt::Message::Record
            @peeked_record = Record.new(@keys, response.fields)
            true
          when Bolt::Message::Success
            # Merge RUN metadata (with t_first) and PULL metadata (with t_last, stats, etc.)
            merged_metadata = @run_metadata.merge(response.metadata)
            @summary = Summary.new(merged_metadata, @query_text, @parameters, @connection)
            @consumed = true
            false
          when Bolt::Message::Failure
            # Create summary from failure metadata before raising exception
            # This allows summary to be accessed even after the failure
            merged_metadata = @run_metadata.merge(response.metadata)
            @summary = Summary.new(merged_metadata, @query_text, @parameters, @connection)
            @consumed = true
            handle_failure(response)
          else
            false
          end
        rescue => e
          @consumed = true
          raise e
        end
      end

      def next
        raise Exceptions::ResultConsumedException if @consumed
        raise Exceptions::NoSuchRecordException, 'No more records' unless has_next?

        record = @peeked_record
        @peeked_record = nil
        @records << record
        record
      end

      def peek
        raise Exceptions::ResultConsumedException if @consumed
        raise Exceptions::NoSuchRecordException, 'No more records' unless has_next?

        @peeked_record
      end

      def single
        record = self.next
        if has_next?
          raise Exceptions::ClientException, 'Expected single record, but found more'
        end
        record
      end

      def each(&block)
        raise Exceptions::ResultConsumedException if @consumed && @records.empty?

        return @records.each(&block) if @consumed

        while has_next?
          block.call(self.next)
        end
      end

      def to_a
        raise Exceptions::ResultConsumedException if @consumed && @records.empty?
        return @records.dup if @consumed

        while has_next?
          self.next
        end
        @records.dup
      end

      def consume
        return @summary if @consumed

        while has_next?
          self.next
        end

        @summary
      end

      def none?
        !has_next?
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
