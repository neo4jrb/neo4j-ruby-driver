# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module DurationNormalizer
        # Convert timeout from seconds (or ActiveSupport::Duration) to
        # milliseconds for the Bolt protocol. A negative timeout is
        # invalid — reject it client-side (matches Java, which raises
        # rather than sending a negative tx_timeout to the server).
        def timeout_to_milliseconds(timeout)
          return if timeout.nil?

          (timeout.to_f * 1000).round.tap do |ms|
            next unless ms.negative?

            raise Exceptions::ClientException,
                  "Transaction timeout must not be negative, but was #{ms}ms"
          end
        end
      end
    end
  end
end
