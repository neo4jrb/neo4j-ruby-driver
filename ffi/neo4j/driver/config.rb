# frozen_string_literal: true

module Neo4j
  module Driver
    class Config
      class TrustStrategy
        class << self
          def trust_all_certificates; end
        end
      end

      class << self
        def default_config
          new
        end
      end
    end
  end
end
