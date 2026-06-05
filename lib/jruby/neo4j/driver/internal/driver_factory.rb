# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # JRuby flavour of the impl-agnostic `Internal::DriverFactory`
      # seam. Subclasses Java's `org.neo4j.driver.internal.DriverFactory`
      # so its `protected` hooks (`getDomainNameResolver`,
      # `createClock`) can be overridden by a further Ruby subclass
      # (testkit-backend's `DriverFactory`) without that subclass
      # naming any Java type. Two converter helpers do the per-impl
      # work:
      #
      #   to_domain_name_resolver(proc)   — wrap a Ruby `proc` returning
      #                                     hostnames into Java's
      #                                     DomainNameResolver SAM.
      #   to_clock(clock)                 — wrap any Ruby `clock` with
      #                                     `#now_millis` into a
      #                                     `java.time.Clock`.
      #
      # `new_instance` adds a Ruby-friendly signature on top of Java's
      # 4-arg form: testkit hands `(uri, auth_or_manager, config)`,
      # we fill in the nil `ClientCertificateManager` and handle the
      # `AuthToken` vs `AuthTokenManager` dispatch.
      class DriverFactory < Java::OrgNeo4jDriverInternal::DriverFactory
        include Ext::ConfigConverter
        include Ext::ExceptionCheckable

        def to_domain_name_resolver(resolver_proc)
          return nil unless resolver_proc

          ->(name) do
            resolver_proc.call(name).map do |addr|
              java.net.InetAddress.get_by_name(addr)
            rescue java.net.UnknownHostException => e
              raise java.lang.RuntimeException.new(e)
            end
          end
        end

        def to_clock(clock)
          Ext::Internal::ClockAdapter.new(clock)
        end

        def new_instance(uri, auth_or_manager, config = {})
          check do
            manager = if auth_or_manager.is_a?(Java::OrgNeo4jDriver::AuthTokenManager)
                        auth_or_manager
                      else
                        org.neo4j.driver.internal.security.StaticAuthTokenManager.new(
                          auth_or_manager || Neo4j::Driver::AuthTokens.none)
                      end
            super(java.net.URI.create(uri.to_s),
                  manager,
                  nil, # ClientCertificateManager — wired in a later slice
                  to_java_config(Neo4j::Driver::Config, **config))
          end
        end
      end
    end
  end
end
