# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module ExceptionCheckable
        include ExceptionMapper

        def check
          yield
        rescue Java::JavaLang::RuntimeException => e
          raise mapped_exception(e)
        end

        def reverse_check
          yield
        rescue Neo4j::Driver::Exceptions::ServiceUnavailableException => e
          raise(throwable(e.cause) || Java::OrgNeo4jDriverExceptions::ServiceUnavailableException.new(e.message))
        rescue Neo4j::Driver::Exceptions::Neo4jException,
          Neo4j::Driver::Exceptions::NoSuchRecordException,
          Neo4j::Driver::Exceptions::UntrustedServerException,
          Neo4j::Driver::Exceptions::IllegalStateException => e
          raise(throwable(e.cause) || e)
        end

        private

        def throwable(e)
          e if e.is_a? Java::JavaLang::Throwable
        end
      end
    end
  end
end
