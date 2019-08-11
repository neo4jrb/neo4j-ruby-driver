# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module ExceptionCheckable
        def check
          yield
        rescue Java::OrgNeo4jDriverV1Exceptions::Neo4jException => e
          e.reraise
        rescue Java::OrgNeo4jDriverV1Exceptions::NoSuchRecordException => e
          raise Neo4j::Driver::Exceptions::NoSuchRecordException, e.message
        rescue Java::OrgNeo4jDriverV1Exceptions::UntrustedServerException => e
          raise Neo4j::Driver::Exceptions::UntrustedServerException, e.message
        rescue Java::JavaLang::IllegalStateException => e
          raise Neo4j::Driver::Exceptions::IllegalStateException, e.message
        end
      end
    end
  end
end
