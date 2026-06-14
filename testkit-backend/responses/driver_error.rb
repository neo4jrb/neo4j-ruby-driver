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
          diagnosticRecord: diagnostic_record_data(@object),
          classification: classification_of(@object),
          rawClassification: @object.try(:raw_classification),
          cause: gql_error(@object.try(:gql_cause)),
          retryable: @object.is_a?(Neo4j::Driver::Exceptions::TransientException) ||
                     @object.is_a?(Neo4j::Driver::Exceptions::ServiceUnavailableException) ||
                     @object.is_a?(Neo4j::Driver::Exceptions::SecurityRetryableException) ||
                     # AuthorizationExpired is always retryable: the driver
                     # re-authenticates and replays (Java treats it the same).
                     @object.is_a?(Neo4j::Driver::Exceptions::AuthorizationExpiredException)
        }.compact
      end

      private

      # A nested GQL error in the cause chain (testkit's DriverError.cause is
      # a GqlError). Same GQL fields as the top error minus the driver-level
      # ones (no id/errorType/code/retryable), recursing through its own
      # gql_cause. nil when the exception has no GQL cause.
      def gql_error(exc)
        return unless exc

        named_entity('GqlError', **{
          gqlStatus: exc.try(:gql_status),
          statusDescription: exc.try(:status_description),
          msg: exc.message,
          diagnosticRecord: diagnostic_record_data(exc),
          classification: classification_of(exc),
          rawClassification: exc.try(:raw_classification),
          cause: gql_error(exc.try(:gql_cause))
        }.compact)
      end

      # testkit always wants a classification string; like Java's backend
      # (orElse "UNKNOWN") an absent/unrecognised one maps to "UNKNOWN".
      def classification_of(exc)
        exc.try(:classification)&.to_s || 'UNKNOWN'
      end

      # diagnostic_record is a Map<String, Value> on the wire. Encode
      # each value through Conversion.to_testkit so testkit gets
      # CypherString/Int/etc. tags.
      def diagnostic_record_data(exc)
        rec = exc.try(:diagnostic_record)
        return nil unless rec

        rec.to_h { |k, v| [k.to_s, self.class.to_testkit(v.respond_to?(:as_ruby_object) ? v.as_ruby_object : v)] }
      end
    end
  end
end
