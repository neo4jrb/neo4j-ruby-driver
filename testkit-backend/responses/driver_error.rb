module TestkitBackend
  module Responses
    class DriverError < Response
      def data
        {
          id: store(@object),
          errorType: @object.class.name,
          msg: @object.message,
          code: @object.try(:code),
          gqlStatus: @object.try(:gql_status),
          statusDescription: @object.try(:status_description),
          diagnosticRecord: gql_diagnostic_record,
          classification: @object.try(:classification)&.to_s,
          rawClassification: @object.try(:raw_classification),
          cause: cause_data,
          retryable: @object.is_a?(Neo4j::Driver::Exceptions::TransientException) ||
                     @object.is_a?(Neo4j::Driver::Exceptions::ServiceUnavailableException)
        }.compact
      end

      private

      def gql_diagnostic_record
        rec = @object.try(:diagnostic_record)
        return nil unless rec

        rec.respond_to?(:to_h) ? rec.to_h : rec
      end

      def cause_data
        cause = @object.try(:gql_cause) || @object.try(:cause)
        return nil unless cause && cause != @object

        DriverError.new(cause).data
      end
    end
  end
end
