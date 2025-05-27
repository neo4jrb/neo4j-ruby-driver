module Neo4j
  module Driver
    module Internal
      module Deprecator
        def self.deprecator
          @deprecator ||= ActiveSupport::Deprecation.new('6.0', 'neo4j-ruby-driver')
        end

        def self.log_warning(old_method, new_method, version)
          deprecator.deprecation_warning(old_method, new_method)
        end
      end
    end
  end
end
