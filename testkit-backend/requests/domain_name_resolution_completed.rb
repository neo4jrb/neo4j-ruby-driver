# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Callback reply carrying a custom DNS resolver's addresses; consumed by
    # the waiting driver thread, so this handler produces no response itself.
    class DomainNameResolutionCompleted < Request
      def process; end
    end
  end
end
