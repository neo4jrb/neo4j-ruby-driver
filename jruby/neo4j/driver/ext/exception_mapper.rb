# frozen_string_literal: true

java_import org.neo4j.driver.v1.exceptions.AuthenticationException
java_import org.neo4j.driver.v1.exceptions.ClientException
java_import org.neo4j.driver.v1.exceptions.NoSuchRecordException
java_import org.neo4j.driver.v1.exceptions.ServiceUnavailableException

module Neo4j
  module Driver
    module Ext
      module ExceptionMapper
        def reraise
          raise mapped_exception.new(code, message, self)
        end

        private

        def mapped_exception
          case self
          when AuthenticationException
            Neo4j::Driver::Exceptions::AuthenticationException
          when ClientException
            Neo4j::Driver::Exceptions::ClientException
          when NoSuchRecordException
            Neo4j::Driver::Exceptions::NoSuchRecordException
          when ServiceUnavailableException
            Neo4j::Driver::Exceptions::ServiceUnavailableException
          else
            self
          end
        end
      end
    end
  end
end
