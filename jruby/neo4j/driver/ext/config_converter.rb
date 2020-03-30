# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module ConfigConverter
        include NeoConverter

        private

        def to_java_config(builder_class, hash)
          hash&.reduce(builder_class.builder) { |object, key_value| object.send(*config_method(*key_value)) }&.build
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
          else
            value = to_neo(value, skip_unknown: true)
          end
          [method, value, unit].compact
        end
      end
    end
  end
end
