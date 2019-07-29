# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Handlers
        class PullAllResponseHandler < ResponseHandler
          delegate :bolt_connection, to: :connection
          delegate :statement_keys, to: :@run_handler
          attr_reader :connection

          def initialize(statement, run_handler, connection, metadata_extractor)
            super(connection)
            @statetement = statement
            @run_handler = run_handler
            @metadate_extractor = metadata_extractor
          end

          def consume
            # @ignore_records = true
            @record = nil
            finalize
          end

          def peek
            @record || ((@record = fetch) unless @finished)
          end

          def next
            peek.tap { @record = nil }
          end

          def on_success(metadata)
            @finished = true
            @summary = extract_result_summary(metadata)

            after_success(metadata)

            @record = nil
            @failure = nil

          end

          def failure
            # bolt_summary if connection.open?
          end

          def after_success(metadata)
          end

          def on_failure(error)
            @finished = true
            @summary = extract_result_summary({})

            after_failure(error)

            @record = nil
            @failure = error
          end

          private

          def fetch
            @run_handler.finalize
            case Bolt::Connection.fetch(bolt_connection, request)
            when -1
              check_status(Bolt::Connection.status(bolt_connection))
            when 1
              InternalRecord.new(@run_handler.statement_keys,
                                 Neo4j::Driver::Value.to_ruby(Bolt::Connection.field_values(bolt_connection)))
            else
              on_success({})
              nil
            end
          end

          def extract_result_summary(metadata)
            InternalResultSummary.new
          end
        end
      end
    end
  end
end
