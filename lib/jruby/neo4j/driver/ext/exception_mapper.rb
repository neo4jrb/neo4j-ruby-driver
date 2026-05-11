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
        java_import org.neo4j.driver.exceptions.TokenExpiredException
        java_import org.neo4j.driver.exceptions.TransactionNestingException
        java_import org.neo4j.driver.exceptions.TransientException
        java_import org.neo4j.driver.exceptions.UnsupportedFeatureException
        java_import org.neo4j.driver.exceptions.UntrustedServerException

        def mapped_exception(exception)
          mapped_neo4j_exception_class(exception)
            &.new(exception.message, **neo4j_exception_kwargs(exception)) ||
            mapped_runtime_exception_class(exception)&.new(exception.message) || exception
        end

        private

        def suppressed(e)
          e.suppressed.map(&method(:mapped_exception))
        end

        # Pull through the GQL fields the testkit DriverError schema
        # asserts on (gql_status, status_description, classification,
        # raw_classification, diagnostic_record). All of these were
        # added to org.neo4j.driver.exceptions.Neo4jException in the
        # GQL-aware Bolt 5.7+ work; auto-aliased on JRuby.
        def neo4j_exception_kwargs(e)
          {
            code: e.code,
            suppressed: suppressed(e),
            gql_status: e.try(:gql_status),
            status_description: e.try(:status_description),
            classification: e.try(:classification)&.to_s,
            raw_classification: e.try(:raw_classification),
            diagnostic_record: e.try(:diagnostic_record)&.then { |d| d.respond_to?(:to_h) ? d.to_h : d }
          }
        end

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
          when TokenExpiredException
            Neo4j::Driver::Exceptions::TokenExpiredException
          when SecurityException
            Neo4j::Driver::Exceptions::SecurityException
          when TransactionNestingException
            Neo4j::Driver::Exceptions::TransactionNestingException
          when UnsupportedFeatureException
            Neo4j::Driver::Exceptions::UnsupportedFeatureException
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
