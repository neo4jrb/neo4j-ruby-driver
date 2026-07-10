# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        # Ruby-side helpers prepended onto Java's
        # `org.neo4j.driver.internal.DriverFactory` (aliased as
        # `Neo4j::Driver::Internal::DriverFactory`). Lets further Ruby
        # subclasses — testkit-backend's
        # `DriverFactoryWithDomainNameResolver` — override the
        # `protected` `getDomainNameResolver` / `create_clock` seams
        # without naming any Java type: testkit hands its Ruby Proc /
        # `TestkitClock` to the converter and gets back something the
        # Java driver consumes (a `DomainNameResolver` SAM /
        # `java.time.Clock`).
        #
        # `new_instance` is a Ruby-friendly wrapper over Java's 4-arg
        # `newInstance` — takes a Ruby Hash config and an optional
        # `ClientCertificateManager` (mutual TLS), and `super`s into the
        # Java method.
        module DriverFactory
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
            ClockAdapter.new(clock)
          end

          def new_instance(uri, auth_token_manager, client_certificate_manager: nil, **config)
            check do
              super(java.net.URI.create(uri.to_s),
                    auth_token_manager,
                    client_certificate_manager,
                    to_java_config(Neo4j::Driver::Config, **config))
            end
          end
        end
      end
    end
  end
end
