# frozen_string_literal: true

module Neo4j
  module Driver
    # Main entry point for creating Neo4j drivers
    module GraphDatabase
      class << self
        def driver(uri, auth_token = nil, **config, &block)
          validate_uri(uri)

          auth = auth_token || AuthTokens.none

          driver = Driver.new(uri, auth, config)

          if block_given?
            begin
              yield driver
            ensure
              driver.close
            end
          else
            driver
          end
        end

        # The JRuby flavor wires a domain_name_resolver block into
        # Java's DriverFactory; MRI doesn't have an equivalent hook yet,
        # so internal_driver collapses to driver and ignores the block.
        # Same API surface keeps the testkit-backend cross-flavour.
        def internal_driver(uri, auth_token = nil, **config, &_domain_name_resolver)
          driver(uri, auth_token, **config)
        end

        private

        def validate_uri(uri)
          parsed_uri = URI(uri)

          raise ArgumentError, 'Scheme must not be null' if parsed_uri.scheme.nil? || parsed_uri.scheme.empty?

          valid_schemes = %w[bolt bolt+s bolt+ssc neo4j neo4j+s neo4j+ssc]
          unless valid_schemes.include?(parsed_uri.scheme)
            raise ArgumentError, "Unsupported URI scheme: #{parsed_uri.scheme}"
          end
        rescue URI::InvalidURIError
          raise ArgumentError, 'Scheme must not be null'
        end
      end
    end
  end
end
