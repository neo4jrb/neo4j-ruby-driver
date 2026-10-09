# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # Base class for the driver's Neo4j-error exceptions — those carrying a
      # server error code plus the GQL status fields (status, description,
      # classification, cause, diagnostic record) and a list of suppressed
      # exceptions. (A few driver exceptions — NoSuchRecordException,
      # IllegalStateException, UntrustedServerException — subclass RuntimeError
      # directly and sit outside this hierarchy.)
      class Neo4jException < RuntimeError
        attr_reader :code, :suppressed, :gql_status, :status_description,
                    :classification, :raw_classification, :diagnostic_record, :gql_cause

        def initialize(message = nil, code: nil, suppressed: nil,
                       gql_status: nil, status_description: nil,
                       classification: nil, raw_classification: nil,
                       diagnostic_record: nil, gql_cause: nil)
          super(message)
          @code = code
          @suppressed = Array(suppressed)
          @gql_status = gql_status
          @status_description = status_description
          @classification = classification
          @raw_classification = raw_classification
          @diagnostic_record = diagnostic_record
          @gql_cause = gql_cause
        end

        def add_suppressed(*exceptions)
          @suppressed.concat(exceptions)
        end
      end
    end
  end
end
