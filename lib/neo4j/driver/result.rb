# frozen_string_literal: true

module Neo4j
  module Driver
    # Represents the result of running a Cypher statement
    class Result
      include Enumerable

      def initialize(connection, keys = [])
        @connection = connection
        @keys = keys
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
            @summary = Summary.new(response.metadata)
            @consumed = true
            false
          when Bolt::Message::Failure
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

        @records.each(&block) if @records.any?
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

    # Represents a single record (row) in a result
    class Record
      def initialize(keys, values)
        @keys = keys
        @values = values
        # Create map with string keys for consistent lookup
        @map = {}
        @keys.each_with_index do |key, idx|
          @map[key.to_s] = @values[idx]
        end
      end

      def keys
        @keys
      end

      def values
        @values
      end

      def [](key)
        case key
        when Integer
          @values[key]
        when String, Symbol
          @map[key.to_s]
        else
          raise ArgumentError, "Invalid key type: #{key.class}"
        end
      end

      def first
        @values.first
      end

      def to_h
        @map.dup
      end

      def each(&block)
        @map.each(&block)
      end
    end

    # Summary of result execution
    class Summary
      attr_reader :metadata

      def initialize(metadata)
        @metadata = metadata
      end

      def query
        Query.new(@metadata.fetch(:query, @metadata))
      end

      def query_type
        type_str = @metadata[:type]
        case type_str
        when 'r' then QueryType::READ_ONLY
        when 'w' then QueryType::WRITE_ONLY
        when 'rw' then QueryType::READ_WRITE
        when 's' then QueryType::SCHEMA_WRITE
        else QueryType::READ_ONLY
        end
      end

      def counters
        @metadata[:stats] || {}
      end

      module QueryType
        READ_ONLY = :read_only
        WRITE_ONLY = :write_only
        READ_WRITE = :read_write
        SCHEMA_WRITE = :schema_write
      end

      class Query
        attr_reader :text, :parameters

        def initialize(metadata)
          @text = metadata[:text] || metadata
          @parameters = metadata[:parameters] || {}
        end
      end
    end
  end
end
