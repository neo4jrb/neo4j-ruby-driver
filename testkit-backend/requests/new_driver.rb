# frozen_string_literal: true

module TestkitBackend
  module Requests
    class NewDriver < Data.define(:uri, :authorization_token, :max_connection_pool_size,
                                  :connection_acquisition_timeout_ms, :max_tx_retry_time_ms,
                                  :connection_timeout_ms, :resolver_registered)
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
          connection_timeout: ms_to_seconds(connection_timeout_ms),
          resolver: build_resolver
        }.compact
      end

      def ms_to_seconds(value)
        value && value / 1000.0
      end

      # When testkit passes resolverRegistered=true, install a Ruby Proc that
      # round-trips through the testkit channel: write a ResolverResolutionRequired
      # response, then read back the matching ResolverResolutionCompleted request
      # and return its addresses. Captures the testkit Connection at NewDriver
      # time — safe because each testkit Connection has its own Registry, so the
      # driver this Proc serves only ever runs handlers on that same connection.
      def build_resolver
        return unless resolver_registered

        tk_conn = connection
        ->(address) { resolve_via_testkit(address, tk_conn) }
      end

      def resolve_via_testkit(address, tk_conn)
        id = SecureRandom.uuid
        tk_conn.write_response(Response::ResolverResolutionRequired.new(id: id, address: address))
        request = tk_conn.read_request
        unless request && request['name'] == 'ResolverResolutionCompleted' && request.dig('data', 'requestId') == id
          raise "Expected ResolverResolutionCompleted(requestId=#{id}), got: #{request.inspect}"
        end

        request['data']['addresses']
      end
    end
  end
end
