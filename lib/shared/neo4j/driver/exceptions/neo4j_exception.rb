# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      class Neo4jException < RuntimeError
        attr_reader :code, :suppressed, :gql_status, :status_description,
                    :classification, :raw_classification, :diagnostic_record

        def initialize(message = nil, code: nil, suppressed: nil,
                       gql_status: nil, status_description: nil,
                       classification: nil, raw_classification: nil,
                       diagnostic_record: nil)
          super(message)
          @code = code
          @suppressed = Array(suppressed)
          @gql_status = gql_status
          @status_description = status_description
          @classification = classification
          @raw_classification = raw_classification
          @diagnostic_record = diagnostic_record
        end

        def add_suppressed(*exceptions)
          @suppressed.concat(exceptions)
        end
      end
    end
  end
end
