# frozen_string_literal: true

java_import org.neo4j.driver.v1.exceptions.NoSuchRecordException
java_import org.neo4j.driver.v1.exceptions.ServiceUnavailableException
java_import org.neo4j.driver.v1.exceptions.AuthenticationException

module Neo4j
  module Driver
    module Ext
      module ExceptionMapper
        def reraise
          raise mapped_exception, message
        end

        private

        def mapped_exception
          case self
          when NoSuchRecordException
            Neo4j::Driver::Exceptions::NoSuchRecordException
          when ServiceUnavailableException
            Neo4j::Driver::Exceptions::ServiceUnavailableException
          when AuthenticationException
            Neo4j::Driver::Exceptions::AuthenticationException
          else
            self
          end
        end
      end
    end
  end
end
