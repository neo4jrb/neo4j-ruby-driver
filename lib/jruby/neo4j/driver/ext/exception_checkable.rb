# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Wraps Java-driver calls at the exception boundary: `check` rescues Java
      # RuntimeExceptions and re-raises them as the mapped Ruby exception;
      # `reverse_check` turns the driver's own Ruby exceptions raised in user
      # callbacks back into the Java exceptions the Java driver expects (reusing
      # the original Java cause when one is present).
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
