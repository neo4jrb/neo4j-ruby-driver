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

        def self.require_non_nil!(obj, message = nil)
          raise ArgumentError, [message, "can't be nil"].compact.join(' ') if obj.nil?
          obj
        end

        # Matches Java's driver-side query-text validation (the JRuby
        # flavour gets this for free from the Java driver). A Query
        # object carries its own text, so only bare strings are checked.
        def self.require_query_text!(query)
          raise ArgumentError, 'Cypher query text should not be null' if query.nil?
          raise ArgumentError, 'Cypher query text should not be an empty string' if query.is_a?(String) && query.strip.empty?

          query
        end

        def self.require_non_nil_credentials!(username, password)
          require_non_nil! username, "Username"
          require_non_nil! password, "Password"
        end
      end
    end
  end
end
