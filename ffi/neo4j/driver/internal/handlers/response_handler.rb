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
              n = Bolt::Connection.fetch_summary(bolt_connection, request)
              if Bolt::Connection.summary_success(bolt_connection) == 1
                extract_result_summary
              else
                failure = Neo4j::Driver::Value.to_ruby(Bolt::Connection.failure(bolt_connection))
                error = Neo4j::Driver::Exceptions::ClientException.new(failure[:code], failure[:message])
                extract_result_summary
                raise error
              end
            end
          end

          private

          def extract_result_summary; end
        end
      end
    end
  end
end
