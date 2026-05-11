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
    end
  end
end
