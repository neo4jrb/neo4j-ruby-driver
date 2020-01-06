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
          when 'load_balancing_strategy'
            value = load_balancing_strategy(value)
          when /Time(out)?$/i
            unit = java.util.concurrent.TimeUnit::SECONDS
          when 'logger'
            method = :with_logging
            value = Neo4j::Driver::Ext::Logger.new(value)
          end
          [method, value, unit].compact
        end

        def load_balancing_strategy(value)
          case value
          when :least_connected
            Config::LoadBalancingStrategy::LEAST_CONNECTED
          when :round_robin
            Config::LoadBalancingStrategy::ROUND_ROBIN
          else
            raise ArgumentError
          end
        end
      end
    end
  end
end
