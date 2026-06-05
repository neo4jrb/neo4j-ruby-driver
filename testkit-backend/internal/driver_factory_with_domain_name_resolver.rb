# frozen_string_literal: true

module TestkitBackend
  module Internal
    # Pure-Ruby `DriverFactory` for testkit-backend — same shape on
    # MRI and JRuby. The two hooks call the parent's converter
    # helpers, so this class never needs to name a Java type:
    #
    #   get_domain_name_resolver  →  Ruby proc, converted to Java's
    #                                 DomainNameResolver SAM on JRuby
    #                                 / identity on MRI.
    #   create_clock              →  `TestkitClock::INSTANCE`,
    #                                 wrapped in a `java.time.Clock`
    #                                 adapter on JRuby / identity on
    #                                 MRI.
    #
    # Built by `NewDriver`; passed the optional resolver proc from
    # testkit when `domainNameResolverRegistered` is set.
    class DriverFactoryWithDomainNameResolver < Neo4j::Driver::Internal::DriverFactory
      def initialize(resolver_proc = nil)
        super()
        @resolver_proc = resolver_proc
      end

      def get_domain_name_resolver
        to_domain_name_resolver(@resolver_proc) || super
      end

      def create_clock
        to_clock(TestkitClock::INSTANCE)
      end
    end
  end
end
