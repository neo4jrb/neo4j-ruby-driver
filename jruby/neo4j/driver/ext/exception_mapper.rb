# frozen_string_literal: true

java_import org.neo4j.driver.v1.exceptions.AuthenticationException
java_import org.neo4j.driver.v1.exceptions.ClientException
java_import org.neo4j.driver.v1.exceptions.DatabaseException
java_import org.neo4j.driver.v1.exceptions.ProtocolException
java_import org.neo4j.driver.v1.exceptions.SecurityException
java_import org.neo4j.driver.v1.exceptions.ServiceUnavailableException
java_import org.neo4j.driver.v1.exceptions.SessionExpiredException
java_import org.neo4j.driver.v1.exceptions.TransientException
java_import org.neo4j.driver.v1.exceptions.UntrustedServerException

module Neo4j
  module Driver
    module Ext
      module ExceptionMapper
        def reraise
          raise mapped_exception(self)
        end

        def mapped_exception(exception)
          mapped_exception_class(exception)&.new(*exception.arguments) || exception
        end

        def arguments
          [code, message, self, suppressed.map(&method(:mapped_exception))]
        end

        def self.reverse_exception_class(exception)
          case exception
          when Neo4j::Driver::Exceptions::ServiceUnavailableException
            ServiceUnavailableException
          else
            nil
          end
        end

        private

        def mapped_exception_class(exception)
          case exception
          when AuthenticationException
            Neo4j::Driver::Exceptions::AuthenticationException
          when ClientException
            Neo4j::Driver::Exceptions::ClientException
          when DatabaseException
            Neo4j::Driver::Exceptions::DatabaseException
          when ProtocolException
            Neo4j::Driver::Exceptions::ProtocolException
          when SecurityException
            Neo4j::Driver::Exceptions::SecurityException
          when ServiceUnavailableException
            Neo4j::Driver::Exceptions::ServiceUnavailableException
          when SessionExpiredException
            Neo4j::Driver::Exceptions::SessionExpiredException
          when TransientException
            Neo4j::Driver::Exceptions::TransientException
          else
            nil
          end
        end
      end
    end
  end
end
