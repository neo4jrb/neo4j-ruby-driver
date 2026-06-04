module TestkitBackend
  module Requests
    # Freeze the driver's internal clock at zero — subsequent
    # `FakeTimeTick` requests advance it. Used by Backend:MockTime
    # tests to deterministically exercise time-sensitive paths
    # (bearer-token expiry, connection idle / max-lifetime, retry
    # backoff). The driver seam (`Internal::Clock`) is per-impl;
    # on MRI it raises until that flavour wires its own mockable
    # clock.
    class FakeTimeInstall < Request
      def process
        Neo4j::Driver::Internal::Clock.install
        named_entity('FakeTimeAck')
      end
    end
  end
end
