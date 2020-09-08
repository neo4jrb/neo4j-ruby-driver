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
        rescue Java::JavaLang::IllegalArgumentException => e
          raise ArgumentError, e.message
        end

        def reverse_check
          yield
        rescue Neo4j::Driver::Exceptions::ServiceUnavailableException => e
          raise(e.cause || org.neo4j.driver.v1.exceptions.ServiceUnavailableException.new(e.message))
        rescue Neo4j::Driver::Exceptions::Neo4jException,
          Neo4j::Driver::Exceptions::NoSuchRecordException,
          Neo4j::Driver::Exceptions::UntrustedServerException,
          Neo4j::Driver::Exceptions::IllegalStateException => e
          raise(e.cause || e)
        end
      end
    end
  end
end
