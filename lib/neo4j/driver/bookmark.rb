# frozen_string_literal: true

module Neo4j
  module Driver
    # Bookmark for transaction causality
    class Bookmark < String
      # Compatibility alias with jruby driver (which wraps java driver)
      alias value itself

      class << self
        alias from new
      end
    end
  end
end
