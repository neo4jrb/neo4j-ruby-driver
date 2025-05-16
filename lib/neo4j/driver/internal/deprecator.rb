module Neo4j
  module Driver
    module Internal
      module Deprecator
        def self.log_warning(old_method, new_method, version)
          @deprecator ||= ActiveSupport::Deprecation.new(version, 'neo4j-ruby-driver')
          @deprecator.deprecation_warning(old_method, new_method)
        end
      end
    end
  end
end
