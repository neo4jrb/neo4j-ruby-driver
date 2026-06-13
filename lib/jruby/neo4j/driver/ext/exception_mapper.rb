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
        java_import org.neo4j.driver.exceptions.SecurityRetryableException
        java_import org.neo4j.driver.exceptions.ServiceUnavailableException
        java_import org.neo4j.driver.exceptions.SessionExpiredException
        java_import org.neo4j.driver.exceptions.TokenExpiredException
        java_import org.neo4j.driver.exceptions.TransactionNestingException
        java_import org.neo4j.driver.exceptions.TransactionTerminatedException
        java_import org.neo4j.driver.exceptions.TransientException
        java_import org.neo4j.driver.exceptions.UnsupportedFeatureException
        java_import org.neo4j.driver.exceptions.UntrustedServerException

        def mapped_exception(exception)
          mapped_neo4j_exception_class(exception)
            &.new(exception.message, **neo4j_exception_kwargs(exception)) ||
            mapped_runtime_exception_class(exception)&.new(exception.message) || exception
        end

        # Like mapped_exception, but chains the original Java exception as
        # `.cause`. At a `raise mapped_exception(e)` site inside a
        # `rescue => e` block Ruby sets `.cause` to the Java exception
        # automatically (which reverse_check round-trips on via
        # `throwable(e.cause)`). At sites that hand the mapped exception
        # off as a *value* (AuthTokenManager#handle_security_exception,
        # AsyncConverter's reject/raise-outside-rescue) there is no such
        # auto-set, so do it explicitly here. Ruby has no `cause=` setter;
        # `raise … cause:` is the only way to attach one.
        def mapped_exception_with_cause(exception)
          mapped = mapped_exception(exception)
          return mapped if mapped.equal?(exception) # unmapped passthrough — no self-cause

          raise mapped, cause: exception
        rescue StandardError => e
          # Only the mapped exception we just raised becomes a return
          # value; anything else (e.g. a bug in mapped_exception) must
          # propagate rather than be silently turned into a value.
          raise unless e.equal?(mapped)

          e
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
        #
        # Java's accessors return Optional<T> for the nullable fields;
        # unwrap to nil/value here so the Ruby exception only ever
        # exposes plain Ruby values — the JRuby driver isn't allowed to
        # leak Java types over the public API.
        def neo4j_exception_kwargs(e)
          {
            code: effective_code(e),
            suppressed: suppressed(e),
            gql_status: unwrap_optional(e.try(:gql_status)),
            status_description: unwrap_optional(e.try(:status_description)),
            classification: unwrap_optional(e.try(:classification))&.to_s,
            raw_classification: unwrap_optional(e.try(:raw_classification)),
            diagnostic_record: unwrap_optional(e.try(:diagnostic_record))&.to_h
          }
        end

        def unwrap_optional(v)
          v.respond_to?(:or_else) ? v.or_else(nil) : v
        end

        # A driver-generated wrapper — e.g. the SessionExpiredException raised
        # for a write against a read-only database — reports code "N/A" but
        # chains the original failure (the shaded BoltFailureException, which
        # carries the real Neo4j code) as its cause. testkit asserts on that
        # original code, so walk the cause chain to the first real code,
        # falling back to the wrapper's own when none is found.
        def effective_code(e, fallback = e.code)
          code = e.try(:code)
          return code if code && code != 'N/A'

          cause = e.respond_to?(:cause) ? e.cause : nil
          cause ? effective_code(cause, fallback) : fallback
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
          when SecurityRetryableException # subclass of SecurityException — match first
            Neo4j::Driver::Exceptions::SecurityRetryableException
          when SecurityException
            Neo4j::Driver::Exceptions::SecurityException
          when TransactionNestingException
            Neo4j::Driver::Exceptions::TransactionNestingException
          when UnsupportedFeatureException
            Neo4j::Driver::Exceptions::UnsupportedFeatureException
          when TransactionTerminatedException # subclass of ClientException — match first
            Neo4j::Driver::Exceptions::TransactionTerminatedException
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
