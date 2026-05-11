module TestkitBackend
  module Responses
    class DriverError < Response
      def data
        {
          id: store(@object),
          errorType: @object.class.name,
          msg: @object.message,
          code: try_value(:code),
          gqlStatus: try_value(:gql_status),
          statusDescription: try_value(:status_description),
          diagnosticRecord: diagnostic_record_data,
          classification: try_value(:classification)&.to_s,
          rawClassification: try_value(:raw_classification),
          retryable: @object.is_a?(Neo4j::Driver::Exceptions::TransientException) ||
                     @object.is_a?(Neo4j::Driver::Exceptions::ServiceUnavailableException)
        }.compact
      end

      private

      # Java methods often return Optional<T>; unwrap if needed.
      def try_value(name)
        return nil unless @object.respond_to?(name)

        v = @object.send(name)
        v.respond_to?(:or_else) ? v.or_else(nil) : v
      end

      # The Java exception's diagnostic_record is a Map<String, Value>
      # of GQL extension fields (CURRENT_SCHEMA, OPERATION, etc.). Each
      # Value needs cypher encoding for the testkit wire.
      def diagnostic_record_data
        rec = try_value(:diagnostic_record)
        return nil unless rec

        rec.each_with_object({}) do |entry, h|
          k, v = entry.is_a?(Array) ? entry : [entry.key, entry.value]
          h[k.to_s] = self.class.to_testkit(v.respond_to?(:as_ruby_object) ? v.as_ruby_object : v)
        end
      end
    end
  end
end
