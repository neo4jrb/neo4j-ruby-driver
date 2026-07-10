# frozen_string_literal: true

module TestkitBackend
  module Internal
    # Pure-Ruby `DriverFactory` for testkit-backend — same shape on
    # MRI and JRuby. The two hooks call the parent's converter helpers,
    # so their bodies never name a Java type:
    #
    #   domain_name_resolver  →  Ruby proc, converted to Java's
    #                             DomainNameResolver SAM on JRuby
    #                             / identity on MRI.
    #   create_clock          →  `TestkitClock::INSTANCE`, wrapped in a
    #                             `java.time.Clock` adapter on JRuby /
    #                             identity on MRI.
    #
    # Each also carries a camelCase `alias` (getDomainNameResolver /
    # createClock) — the only spot that names the Java-side hook, so the
    # JRuby-loaded Java DriverFactory can dispatch back into these Ruby
    # overrides.
    #
    # Built by `NewDriver`; passed the optional resolver proc from
    # testkit when `domainNameResolverRegistered` is set.
    class DriverFactoryWithDomainNameResolver < Neo4j::Driver::Internal::DriverFactory
      def initialize(resolver_proc = nil)
        super()
        @resolver_proc = resolver_proc
      end

      # The hooks are authored under their rubyish snake_case names (the
      # ones the MRI base calls). This is the one place aware that on
      # JRuby the base is Java's DriverFactory, which invokes these hooks
      # by their camelCase names — so each snake_case method is also
      # exposed to Java via an `alias`. An aliased name overrides an
      # inherited Java method just as a defined one does, and `super`
      # inside still resolves by the original definition name, reaching
      # the Java implementation through JRuby's getter mapping. (Ruby's
      # own snake_case->Java mapping only covers Ruby-calling-into-Java,
      # not Java dispatching back into a Ruby override — hence the alias.)
      def domain_name_resolver
        to_domain_name_resolver(@resolver_proc) || super
      end
      alias getDomainNameResolver domain_name_resolver

      def create_clock
        to_clock(TestkitClock::INSTANCE)
      end
      alias createClock create_clock
    end
  end
end
