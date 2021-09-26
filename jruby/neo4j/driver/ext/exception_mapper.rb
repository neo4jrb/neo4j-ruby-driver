# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module ExceptionMapper
        java_import org.neo4j.driver.exceptions.AuthenticationException
        java_import org.neo4j.driver.exceptions.AuthorizationExpiredException
        java_import org.neo4j.driver.exceptions.ClientException
        java_import org.neo4j.driver.exceptions.ConnectionReadTimeoutException
        java_import org.neo4j.driver.exceptions.DatabaseException
        java_import org.neo4j.driver.exceptions.DiscoveryException
        java_import org.neo4j.driver.exceptions.FatalDiscoveryException
        java_import org.neo4j.driver.exceptions.ProtocolException
        java_import org.neo4j.driver.exceptions.ResultConsumedException
        java_import org.neo4j.driver.exceptions.SecurityException
        java_import org.neo4j.driver.exceptions.ServiceUnavailableException
        java_import org.neo4j.driver.exceptions.SessionExpiredException
        java_import org.neo4j.driver.exceptions.TransactionNestingException
        java_import org.neo4j.driver.exceptions.TransientException
        java_import org.neo4j.driver.exceptions.UntrustedServerException

        def mapped_exception(exception)
          mapped_neo4j_exception_class(exception)&.new(*arguments(exception)) ||
            mapped_runtime_exception_class(exception)&.new(exception.message) || exception
        end

        def arguments(e)
          [e.code, e.message, e.suppressed.map(&method(:mapped_exception))]
        end

        private

        def mapped_neo4j_exception_class(exception_class)
          case exception_class
          when AuthenticationException
            Neo4j::Driver::Exceptions::AuthenticationException
          when AuthorizationExpiredException
            Neo4j::Driver::Exceptions::AuthorizationExpiredException
          when FatalDiscoveryException
            Neo4j::Driver::Exceptions::FatalDiscoveryException
          when ResultConsumedException
            Neo4j::Driver::Exceptions::ResultConsumedException
          when TransactionNestingException
            Neo4j::Driver::Exceptions::TransactionNestingException
          when ClientException
            Neo4j::Driver::Exceptions::ClientException
          when ConnectionReadTimeoutException
            Neo4j::Driver::Exceptions::ConnectionReadTimeoutException
          when DatabaseException
            Neo4j::Driver::Exceptions::DatabaseException
          when DiscoveryException
            Neo4j::Driver::Exceptions::DiscoveryException
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

        def mapped_runtime_exception_class(exception_class)
          case exception_class
          when Java::OrgNeo4jDriverExceptions::NoSuchRecordException
            Neo4j::Driver::Exceptions::NoSuchRecordException
          when Java::OrgNeo4jDriverExceptions::UntrustedServerException
            Neo4j::Driver::Exceptions::UntrustedServerException
          when Java::JavaLang::IllegalStateException
            Neo4j::Driver::Exceptions::IllegalStateException
          when Java::JavaLang::IllegalArgumentException
            ArgumentError
          else
            nil
          end
        end
      end
    end
  end
end
