# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # Shared helpers for building Bolt protocol extras maps (RUN /
      # BEGIN / etc). Kept tiny on purpose — we don't depend on
      # ActiveSupport so this is the local replacement for
      # `Hash#compact_blank!`.
      module Extras
        # Use as a Hash#reject! predicate to drop nil and
        # empty-collection values:
        #
        #   extras.reject!(&Internal::Extras::BLANK)
        #
        # Matches what other drivers serialise — testkit stub scripts
        # strictly compare the map, so an empty `tx_metadata: {}` or
        # an empty `bookmarks: []` left in the payload would mismatch.
        BLANK = ->(_, v) { v.nil? || (v.respond_to?(:empty?) && v.empty?) }
      end
    end
  end
end
