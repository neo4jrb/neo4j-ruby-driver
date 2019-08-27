# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module StatementValidator
        def self.validate!(parameters)
          unless parameters.nil? || parameters.is_a?(Hash)
            raise ArgumentError,
                  "The parameters should be provided as Map type. Unsupported parameters type: #{parameters.class.name}"
          end
        end
      end
    end
  end
end
