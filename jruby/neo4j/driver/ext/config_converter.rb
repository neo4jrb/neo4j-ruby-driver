# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module ConfigConverter
        include NeoConverter

        private

        def to_java_config(builder_class, **hash)
          hash.compact.reduce(builder_class.builder) { |object, key_value| object.send(*config_method(*key_value)) }.build
        end

        def config_method(key, value)
          method = :"with_#{key}"
          unit = nil
          case key.to_s
          when 'encryption', 'driver_metrics'
            method = :"without_#{key}" unless value
            value = nil
          when 'timeout'
            value = java.time.Duration.ofMillis(Driver::Internal::DurationNormalizer.milliseconds(value))
          when /time(out)?$/
            value = Driver::Internal::DurationNormalizer.milliseconds(value)
            unit = java.util.concurrent.TimeUnit::MILLISECONDS
          when 'logger'
            method = :with_logging
            value = Neo4j::Driver::Ext::Logger.new(value)
          when 'resolver'
            proc = value
            value = ->(address) { java.util.HashSet.new(proc.call(address)) }
          when 'bookmarks'
            return [method, *value]
          when 'trust_strategy'
            value = trust_strategy(**value)
          else
            value = to_neo(value, skip_unknown: true)
          end
          [method, value, unit].compact
        end

        def trust_strategy(**config)
          strategy = config[:strategy]
          case strategy
          when :trust_custom_certificates
            Config::TrustStrategy.trust_custom_certificates_signed_by(*config[:cert_files].map(&java.io.File.method(:new)))
          else
            Config::TrustStrategy.send(strategy)
          end.send(revocation_strategy(config[:revocation_strategy])).send(hostname_verification(config[:hostname_verification]))
        end

        def revocation_strategy(revocation_strategy)
          return :itself unless revocation_strategy

          case revocation_strategy
          when Neo4j::Driver::Internal::RevocationStrategy::NO_CHECKS
            'without_certificate_revocation_checks'
          else
            "with_#{revocation_strategy}_revocation_checks"
          end
        end

        def hostname_verification(hostname_verification)
          "with#{'out' unless hostname_verification}_hostname_verification"
        end
      end
    end
  end
end
