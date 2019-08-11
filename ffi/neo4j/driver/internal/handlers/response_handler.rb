# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Handlers
        class ResponseHandler
          delegate :bolt_connection, to: :connection
          attr_reader :connection
          attr_accessor :request, :previous

          def initialize(connection)
            @connection = connection
          end

          def finalize
            return if @finished
            @finished = true
            begin
              previous&.finalize
            ensure
              Bolt::Connection.fetch_summary(bolt_connection, request)
              check_summary_failure
            end
          end

          private

          def check_summary_failure
            summary
            if Bolt::Connection.summary_success(bolt_connection) == 1
              after_success(nil)
            else
              failure = Value::ValueAdapter.to_ruby(Bolt::Connection.failure(bolt_connection))
              raise Exceptions::ClientException.new(failure[:code], failure[:message])
            end
          end

          def summary; end

          def after_success(metadata); end
        end
      end
    end
  end
end
