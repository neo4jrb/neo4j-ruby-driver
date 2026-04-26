# frozen_string_literal: true

module TestkitBackend
  # Response value objects. Each subclass is a `Data.define(...)` whose
  # members become the JSON `data` payload, with snake_case → camelCase
  # conversion handled by the shared mixin.
  #
  # Override #payload when the default (camelize members → hash) doesn't fit.
  module Response
    module Mixin
      # Default JSON `name` is the unqualified class name.
      def name
        self.class.name.split('::').last
      end

      # Default `data` payload: members serialised with camelCase keys.
      def payload
        members.each_with_object({}) { |m, acc| acc[Casing.camel(m)] = public_send(m) }
      end

      # Frame to ship over the testkit wire.
      def to_payload
        { 'name' => name, 'data' => payload }
      end
    end

    class Driver < Data.define(:id)
      include Mixin
    end

    class Session < Data.define(:id)
      include Mixin
    end

    class Transaction < Data.define(:id)
      include Mixin
    end

    class Result < Data.define(:id, :keys)
      include Mixin
    end

    class Record < Data.define(:values)
      include Mixin

      def self.from_driver_record(record)
        new(values: record.values.map(&Cypher.method(:from_ruby)))
      end
    end

    class NullRecord < Data.define
      include Mixin
    end

    class Bookmarks < Data.define(:bookmarks)
      include Mixin
    end

    class FeatureList < Data.define(:features)
      include Mixin
    end

    class RunTest < Data.define
      include Mixin
    end

    class RecordList < Data.define(:records)
      include Mixin
    end

    class Summary
      include Mixin

      def initialize(payload)
        @payload = payload
      end

      def payload
        @payload
      end
    end

    class DriverError < Data.define(:id, :error_type, :code, :msg, :retryable)
      include Mixin

      def self.from(exception)
        new(
          id: SecureRandom.hex(8),
          error_type: exception.class.name,
          code: exception.respond_to?(:code) ? exception.code : nil,
          msg: exception.message,
          retryable: exception.is_a?(Neo4j::Driver::Exceptions::TransientException)
        )
      end
    end

    class FrontendError < Data.define(:msg)
      include Mixin
    end

    class BackendError < Data.define(:msg)
      include Mixin
    end

    class UnknownType < Data.define(:message)
      include Mixin

      def name
        'UnknownTypeError'
      end
    end
  end
end
