# frozen_string_literal: true

module Neo4j::Driver::Internal::Util
  class ErrorUtil
    DEFAULT_CONN_TERMINATED_REASON = 'Please ensure that your database is listening on the correct host and port and '\
      'that you have compatible encryption settings both on Neo4j server and driver. '\
      'Note that the default encryption setting has changed in Neo4j 4.0.'.freeze

    SEC_EXCEPTION_CODE_MAPPING = {
      'neo.clienterror.security.unauthorized': Neo4j::Driver::Exceptions::AuthenticationException,
      'neo.clienterror.security.authorizationexpired': Neo4j::Driver::Exceptions::AuthorizationExpiredException,
      'neo.clienterror.security.tokenexpired': Neo4j::Driver::Exceptions::TokenExpiredException
    }.freeze

    class << self
      def new_connection_terminated_error(reason)
        reason ||= DEFAULT_CONN_TERMINATED_REASON
        Neo4j::Driver::Exceptions::ServiceUnavailableException.new("Connection to the database terminated. #{reason}")
      end

      def new_result_consumed_error
        Neo4j::Driver::Exceptions::ResultConsumedException.new(
          'Cannot access records on this result any more as the result has already been consumed '\
          'or the query runner where the result is created has already been closed.'
        )
      end

      def new_neo4j_error(code, message)
        exception_class = case extract_error_class(code)
                          when 'ClientError'
                            if extract_error_sub_class(code) == 'Security'
                              SEC_EXCEPTION_CODE_MAPPING[code.downcase] || Neo4j::Driver::Exceptions::SecurityException
                            else
                              code.casecmp?('Neo.ClientError.Database.DatabaseNotFound') ? Neo4j::Driver::Exceptions::FatalDiscoveryException : Neo4j::Driver::Exceptions::ClientException
                            end
                          when 'TransientError'
                            Neo4j::Driver::Exceptions::TransientException
                          else
                            Neo4j::Driver::Exceptions::DatabaseException
                          end

        exception_class.new(code, message)
      end

      def fatal?(error)
        return true unless error.is_a?(Neo4j::Driver::Exceptions::Neo4jException)

        error_code = error.code&.downcase
        return true if protocol_violation_error?(error_code)
        return false if client_or_transient_error?(error_code)
        # TO DO: last two if condition makes this method return nil, should we change it to only return boolean
      end

      def rethrow_async_exception(exception)
        error = exception.cause
        internal_cause = InternalExceptionCause.new(nil, error.backtrace)
        error.add_suppressed(internal_cause) # TO DO: Ruby exception don't support supressed, how to handle this?

        # do not include Thread.current and this method in the stacktrace
        current_stack_trace = Thread.current.backtrace.drop(2)
        error.set_backtrace(current_stack_trace)

        org.neo4j.driver.internal.shaded.io.netty.util.internal.PlatformDependent.throw_exception(error)
      end

      def add_suppressed(main_error, error)
        main_error.add_suppressed(error) if main_error != error
      end

      def get_root_cause(error)
        java.util.Objects.require_non_null(error)

        error.cause ? get_root_cause(error.cause) : error
      end

      # Exception which is merely a holder of an async stacktrace, which is not the primary stacktrace users are interested in.
      # Used for blocking API calls that block on async API calls.
      class InternalExceptionCause < RuntimeError
        def initialize(message, backtrace)
          super(message)
          set_backtrace(backtrace)
        end
      end

      private

      def extract_error_class(code)
        extract_class_from_code(code, 2)
      end

      def extract_error_sub_class(code)
        extract_class_from_code(code, 3)
      end

      def extract_class_from_code(code, parts_counts)
        parts = code.split('.')
        parts.length < parts_counts ? '' : parts[parts_counts - 1]
      end

      def protocol_violation_error?(error_code)
        return false if error_code.nil?

        error_code.start_with?('neo.clienterror.request')
      end

      def client_or_transient_error(error_code)
        return false if error_code.nil?

        error_code.include?('clienterror') || error_code.include?('transienterror')
      end
    end
  end
end
