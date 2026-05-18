# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module ConfigConverter
        include NeoConverter
        include Driver::Internal::DurationNormalizer

        private

        def to_java_config(builder_class, **hash)
          apply_to(builder_class.builder, **hash).build
        end

        def apply_to(builder, **hash)
          hash.compact.reduce(builder) { |object, (key, value)| object.send(*config_method(key, value)) }
        end

        def config_method(key, value)
          method = :"with_#{key}"
          unit = nil
          case key.to_s
          when 'encryption', 'hostname_verification'
            method = :"without_#{key}" unless value
            value = nil
          when 'timeout'
            value = java.time.Duration.ofMillis(timeout_to_milliseconds(value))
          when /time(out)?$/, 'routing_table_purge_delay'
            value = timeout_to_milliseconds(value) || -1
            unit = java.util.concurrent.TimeUnit::MILLISECONDS
          when 'logger'
            method = :with_logging
            value = Neo4j::Driver::Ext::Logger.new(value)
          when 'resolver'
            # LinkedHashSet (not HashSet) preserves the order the caller's
            # resolver returned. The Java driver's ServerAddressResolver
            # contract is `Set<ServerAddress>`, but its routing layer
            # iterates that Set in its natural order to pick a router to
            # probe — with a plain HashSet that's hash-of-host:port order,
            # so the driver effectively picks at random and tests like
            # test_should_read_successfully_on_empty_discovery_result_using_session_run
            # (which expect probes in the resolver-returned order) become
            # flaky.
            proc = value
            value = ->(address) { java.util.LinkedHashSet.new(proc.call(address)) }
          when 'bookmarks'
            return [method, *value]
          when 'trust_strategy'
            value = trust_strategy(**value)
          when 'revocation_strategy'
            method = case value
                     when Neo4j::Driver::Internal::RevocationStrategy::NO_CHECKS
                       'without_certificate_revocation_checks'
                     else
                       "with_#{value}_revocation_checks"
                     end
          when 'notification_config'
            value = notification_config(**value)
          else
            value = to_neo(value, skip_unknown: true)
          end
          [method, value, unit].compact
        end

        def trust_strategy(**config)
          strategy = config.delete(:strategy)
          trust_strategy =
            case strategy
            when :trust_custom_certificates
              Config::TrustStrategy
                .trust_custom_certificate_signed_by(*config.delete(:cert_files).map(&java.io.File.method(:new)))
            else
              Config::TrustStrategy.send(strategy)
            end
          apply_to(trust_strategy, **config)
        end

        def notification_config(minimum_severity: nil, disabled_categories: nil)
          org.neo4j.driver.internal.InternalNotificationConfig.new(
            value_of(org.neo4j.driver.internal.InternalNotificationSeverity, minimum_severity).or_else(nil),
            disabled_categories
              &.map { |value| value_of(org.neo4j.driver.NotificationClassification, value) }
              &.then(&java.util.HashSet.method(:new)))
        end

        def value_of(klass, value)
          klass.value_of(value&.to_s&.upcase)
        end
      end
    end
  end
end
