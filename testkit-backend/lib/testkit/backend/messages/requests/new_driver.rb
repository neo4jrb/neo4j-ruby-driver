module Testkit::Backend::Messages
  module Requests
    class NewDriver < Request
      def process
        reference('Driver')
      end

      def to_object
        Neo4j::Driver::GraphDatabase.driver(
          uri,
          Request.object_from(authorizationToken),
          user_agent: userAgent,
          connection_timeout: timeout_duration(connectionTimeoutMs),
          fetch_size: fetchSize,
          max_transaction_retry_time: timeout_duration(maxTxRetryTimeMs))
      end
    end
  end
end