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
            previous&.finalize
            n = Bolt::Connection.fetch_summary(bolt_connection, request)
            return n if Bolt::Connection.summary_success(bolt_connection) == 1
            failure = Neo4j::Driver::Value.to_ruby(Bolt::Connection.failure(bolt_connection))
            raise Neo4j::Driver::Exceptions::ClientException.new(failure[:code], failure[:message])
          end
        end
      end
    end
  end
end
