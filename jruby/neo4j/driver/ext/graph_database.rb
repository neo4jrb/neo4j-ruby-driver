# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module GraphDatabase
        extend AutoClosable
        include ExceptionCheckable

        auto_closable :driver, :routing_driver

        def driver(uri, auth_token = Neo4j::Driver::AuthTokens.none, config = nil)
          check do
            java_method(:driver, [java.lang.String, org.neo4j.driver.v1.AuthToken, org.neo4j.driver.v1.Config])
              .call(uri.to_s, auth_token, to_java_config(config))
          end
        end

        def routing_driver(routing_uris, auth_token, config)
          check { super(routing_uris.map { |uri| java.net.URI.create(uri.to_s) }, auth_token, to_java_config(config)) }
        end

        private

        def to_java_config(hash)
          hash&.reduce(Neo4j::Driver::Config.build) { |object, key_value| object.send(*config_method(*key_value)) }
            &.to_config
        end

        def config_method(key, value)
          method = :"with_#{key}"
          unit = nil
          case key.to_s
          when 'encryption'
            unless value
              method = :without_encryption
              value = nil
            end
          when /Time(out)?$/i
            value = Driver::Internal::DurationNormalizer.milliseconds(value)
            unit = java.util.concurrent.TimeUnit::MILLISECONDS
          when 'logger'
            method = :with_logging
            value = Neo4j::Driver::Ext::Logger.new(value)
          when 'resolver'
            proc = value
            value = ->(address) { java.util.HashSet.new(proc.call(address)) }
          end
          [method, value, unit].compact
        end
      end
    end
  end
end
