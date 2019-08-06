# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class InternalStatementResult
        include Enumerable

        # delegate :consume, :summary, to: :@pull_all_handler
        delegate :consume, :failure, :summary, :finalize, to: :@pull_all_handler

        def initialize(run_handler, pull_all_handler)
          @run_handler = run_handler
          @pull_all_handler = pull_all_handler
        end

        def single
          @pull_all_handler.next.tap do |record|
            raise Exceptions::NoSuchRecordException.empty unless record
            raise Exceptions::NoSuchRecordException.too_many if has_next?
          end
        end

        def next
          @pull_all_handler.next.tap do |record|
            raise Exceptions::NoSuchRecordException.no_more unless record
          end
        end

        def peek
          @pull_all_handler.peek.tap do |record|
            raise Exceptions::NoSuchRecordException.no_peek_past unless record
          end
        end

        def has_next?
          @pull_all_handler.peek
        end

        def each
          yield @pull_all_handler.next while has_next?
        end

        def keys
          @keys ||= begin
            @pull_all_handler.peek
            @pull_all_handler.statement_keys
          end
        end
      end
    end
  end
end
