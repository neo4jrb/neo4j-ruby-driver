# frozen_string_literal: true

module Neo4j
  module Driver
    class Config
      class TrustStrategy
        def self.trust_all_certificates; end
      end
    end
  end
end
