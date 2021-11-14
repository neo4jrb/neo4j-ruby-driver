# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Validator
        def self.require_hash_parameters!(parameters)
          require_hash!(parameters) do
            "The parameters should be provided as Map type. Unsupported parameters type: #{parameters.class.name}"
          end
        end

        def self.require_hash!(obj)
          raise(ArgumentError, yield) unless obj.nil? || obj.is_a?(Hash)
        end

        def self.require_non_nil!(obj, message)
          raise ArgumentError, "#{message} can't be nil" if obj.nil?
        end

        def self.require_non_nil_credentials!(username, password)
          require_non_nil! username, "Username"
          require_non_nil! password, "Password"
        end
      end
    end
  end
end
