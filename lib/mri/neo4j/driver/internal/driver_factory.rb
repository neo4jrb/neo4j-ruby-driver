# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # MRI flavour of the impl-agnostic `Internal::DriverFactory`
      # seam. MRI doesn't have Java-style hooks for the resolver or
      # the clock, so the converters are identity and the hook
      # methods default to nil — testkit-backend's subclass may
      # still override them, but on MRI the overrides are no-ops
      # because nothing consults them yet.
      class DriverFactory
        def to_domain_name_resolver(resolver_proc)
          resolver_proc
        end

        def to_clock(clock)
          clock
        end

        def get_domain_name_resolver
          nil
        end

        def create_clock
          nil
        end

        def new_instance(uri, auth_token_manager, config = {})
          # MRI's `GraphDatabase.driver` takes an `AuthToken`; managed
          # auth (Feature:Auth:Managed) is JRuby-only for now, so
          # testkit only ever hands us static managers here. Pull the
          # token straight out — the manager's retry semantics are
          # irrelevant on MRI until that path lands.
          GraphDatabase.driver(uri, auth_token_manager.get_token, **config)
        end
      end
    end
  end
end
