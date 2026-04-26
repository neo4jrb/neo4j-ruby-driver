# frozen_string_literal: true

module TestkitBackend
  module Requests
    class NewDriver < Data.define(:uri, :authorization_token, :max_connection_pool_size,
                                  :connection_acquisition_timeout_ms, :max_tx_retry_time_ms,
                                  :connection_timeout_ms)
      include Request

      def execute
        driver = Neo4j::Driver::GraphDatabase.driver(uri, build_auth, **build_options)
        Response::Driver.new(id: registry.store(driver))
      end

      private

      def build_auth
        return Neo4j::Driver::AuthTokens.none if authorization_token.nil?

        # testkit wraps the token as {name: 'AuthorizationToken', data: {...}}
        token = authorization_token['data'] || authorization_token
        case token['scheme']
        when 'basic'
          Neo4j::Driver::AuthTokens.basic(token['principal'], token['credentials'])
        else
          Neo4j::Driver::AuthTokens.none
        end
      end

      def build_options
        {
          max_connection_pool_size: max_connection_pool_size,
          connection_acquisition_timeout: ms_to_seconds(connection_acquisition_timeout_ms),
          max_transaction_retry_time: ms_to_seconds(max_tx_retry_time_ms),
          connection_timeout: ms_to_seconds(connection_timeout_ms)
        }.compact
      end

      def ms_to_seconds(value)
        value && value / 1000.0
      end
    end
  end
end
