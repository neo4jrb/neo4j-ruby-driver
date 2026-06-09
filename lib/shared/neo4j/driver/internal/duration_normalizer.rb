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

          # Check the sign before rounding: a tiny negative timeout
          # (e.g. -0.4ms) would otherwise round to 0 and slip through.
          ms = timeout.to_f * 1000
          raise Exceptions::ClientException,
                "Transaction timeout must not be negative, but was #{ms}ms" if ms.negative?

          ms.round
        end
      end
    end
  end
end
