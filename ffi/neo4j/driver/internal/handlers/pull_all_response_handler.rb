# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Handlers
        class PullAllResponseHandler < ResponseHandler
          delegate :bolt_connection, to: :connection
          delegate :statement_keys, to: :run_handler
          attr_reader :connection

          def initialize(statement, run_handler, connection, metadata_extractor)
            super(connection)
            @statement = statement
            @previous = run_handler
            @metadate_extractor = metadata_extractor
            @records = []
          end

          def consume
            @ignore_records = true
            @records.clear
            finalize
            @summary
          rescue StandardError => e
            on_failure(e)
            raise e
          end

          def summary
            unless @finished
              while (record = fetch)
                @records << record
              end
            end
            @summary ||= Summary::InternalResultSummary.new(@statement, run_handler.result_available_after,
                                                            bolt_connection)
          end

          def peek
            @records.first || ((@records << fetch).first unless @finished)
          end

          def next
            peek
            @records.shift
          end

          def on_success
            @finished = true
            summary

            after_success(nil)

            @failure = nil
          end

          def failure
            summary
            super
          end

          def on_failure(error)
            @failure = error
            summary
            @finished = true

            after_failure(error)
          end

          def finalize
            summary unless @ignore_records
            super
          end

          private

          def run_handler
            @previous
          end

          def fetch
            run_handler.finalize
            bolt_connection_fetch = Bolt::Connection.fetch(bolt_connection, request)
            case bolt_connection_fetch
            when -1
              check_status(Bolt::Connection.status(bolt_connection))
            when 1
              InternalRecord.new(run_handler.statement_keys,
                                 Value::ValueAdapter.to_ruby(Bolt::Connection.field_values(bolt_connection)))
            else
              @finished = true
              check_summary_failure
              nil
            end
          rescue StandardError => e
            on_failure(e) unless @failure
            raise e
          end
        end
      end
    end
  end
end
