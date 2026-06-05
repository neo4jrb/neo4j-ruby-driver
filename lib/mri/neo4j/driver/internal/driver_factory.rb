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

        def new_instance(uri, auth_or_manager, config = {})
          # MRI's `GraphDatabase.driver` takes an `AuthToken`; managed
          # auth is JRuby-only for now, so testkit never passes a
          # manager here on MRI.
          GraphDatabase.driver(uri, auth_or_manager, **config)
        end
      end
    end
  end
end
