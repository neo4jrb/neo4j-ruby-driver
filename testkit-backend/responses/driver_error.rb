module TestkitBackend
  module Responses
    # Serialises a driver exception into the testkit DriverError shape.
    # All Java Optional<T> values are unwrapped by the JRuby
    # ExceptionMapper before they reach us, so every accessor here
    # returns a plain Ruby value or nil — no Optional plumbing.
    class DriverError < Response
      def data
        {
          id: store(@object),
          errorType: @object.class.name,
          msg: @object.message,
          code: @object.try(:code),
          gqlStatus: @object.try(:gql_status),
          statusDescription: @object.try(:status_description),
          diagnosticRecord: diagnostic_record_data,
          classification: @object.try(:classification)&.to_s,
          rawClassification: @object.try(:raw_classification),
          retryable: @object.is_a?(Neo4j::Driver::Exceptions::TransientException) ||
                     @object.is_a?(Neo4j::Driver::Exceptions::ServiceUnavailableException)
        }.compact
      end

      private

      # diagnostic_record is a Map<String, Value> on the wire. Encode
      # each value through Conversion.to_testkit so testkit gets
      # CypherString/Int/etc. tags.
      def diagnostic_record_data
        rec = @object.try(:diagnostic_record)
        return nil unless rec

        rec.to_h { |k, v| [k.to_s, self.class.to_testkit(v.respond_to?(:as_ruby_object) ? v.as_ruby_object : v)] }
      end
    end
  end
end
