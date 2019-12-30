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
        rescue StandardError => e
          raise(e.cause || ExceptionMapper.reverse_exception_class(e)&.new('') || e)
        end
      end
    end
  end
end
