# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Callback reply carrying a custom address resolver's result; consumed by
    # the waiting driver thread, so this handler produces no response itself.
    class ResolverResolutionCompleted < Request
      def process; end
    end
  end
end
