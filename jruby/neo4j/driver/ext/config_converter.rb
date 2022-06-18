# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module ConfigConverter
        include NeoConverter

        private

        def to_java_config(builder_class, **hash)
          apply_to(builder_class.builder, **hash).build
        end

        def apply_to(builder, **hash)
          hash.compact.reduce(builder) { |object, key_value| object.send(*config_method(*key_value)) }
        end

        def config_method(key, value)
          method = :"with_#{key}"
          unit = nil
          case key.to_s
          when 'encryption', 'driver_metrics', 'hostname_verification'
            method = :"without_#{key}" unless value
            value = nil
          when 'timeout'
            value = java.time.Duration.ofMillis(Driver::Internal::DurationNormalizer.milliseconds(value))
          when /time(out)?$/
            value = Driver::Internal::DurationNormalizer.milliseconds(value) || -1
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
          when 'revocation_strategy'
            method = case value
                     when Neo4j::Driver::Internal::RevocationStrategy::NO_CHECKS
                       'without_certificate_revocation_checks'
                     else
                       "with_#{value}_revocation_checks"
                     end
          else
            value = to_neo(value, skip_unknown: true)
          end
          [method, value, unit].compact
        end

        def trust_strategy(**config)
          strategy = config.delete(:strategy)
          trust_strategy =
            case strategy
            when :trust_custom_ca_signed_certificates
              Config::TrustStrategy
                .trust_custom_certificate_signed_by(*config.delete(:cert_files).map(&java.io.File.method(:new)))
            else
              Config::TrustStrategy.send(strategy)
            end
          apply_to(trust_strategy, **config)
        end
      end
    end
  end
end
