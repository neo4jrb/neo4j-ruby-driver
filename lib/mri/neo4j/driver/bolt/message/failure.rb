# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Message
        # Failure response from Neo4j server.
        #
        # Two wire shapes, both handled by #to_exception:
        #   * Legacy (pre-Bolt 5.7): { code:, message: }.
        #   * GQL (Bolt 5.7+): { gql_status:, description:, message:, neo4j_code:,
        #     diagnostic_record:, cause: } — `cause` nests the same shape.
        # Since the driver speaks 5.7, a legacy failure is *synthesised* into the
        # GQL shape (gql_status 50N42, default diagnostic record) so the exception
        # exposes the same fields regardless of the server's protocol version —
        # matching the Java driver's GqlStatusException behaviour.
        class Failure
          # Code-prefix → driver exception class. Order matters: more specific
          # patterns must come first.
          EXCEPTION_FOR_CODE = [
            [%r{^Neo\.ClientError\.Security\.Unauthorized},         Exceptions::AuthenticationException],
            [%r{^Neo\.ClientError\.Security\.AuthorizationExpired}, Exceptions::AuthorizationExpiredException],
            [%r{^Neo\.ClientError\.Security\.TokenExpired},         Exceptions::TokenExpiredException],
            [%r{^Neo\.ClientError\.Security},                       Exceptions::SecurityException],
            [%r{^Neo\.ClientError\.Database\.DatabaseNotFound},     Exceptions::FatalDiscoveryException],
            [%r{^Neo\.ClientError},                                 Exceptions::ClientException],
            [%r{^Neo\.TransientError},                              Exceptions::TransientException],
            [%r{^Neo\.DatabaseError},                               Exceptions::DatabaseException]
          ].freeze

          # Two `TransientError` codes the server may send that are actually
          # non-retryable: the driver rewrites them to their `ClientError` form
          # (so they map to a non-retryable ClientException, not a retryable
          # TransientException) and surfaces the rewritten code. Mirrors the
          # Java driver's ErrorUtil special-case; testkit's
          # test_should_not_retry_non_retryable_tx_failures asserts both the
          # rewritten code and that the managed-tx executor does not retry.
          CODE_REWRITES = {
            'Neo.TransientError.Transaction.Terminated' => 'Neo.ClientError.Transaction.Terminated',
            'Neo.TransientError.Transaction.LockClientStopped' => 'Neo.ClientError.Transaction.LockClientStopped'
          }.freeze

          # GQL diagnostic-record keys the server may omit; filled with these
          # defaults so the record is always complete (mirrors the Java driver).
          DEFAULT_DIAGNOSTIC_RECORD = { OPERATION: '', OPERATION_CODE: '0', CURRENT_SCHEMA: '/' }.freeze

          # Fallback GQL status for a legacy (non-GQL) failure: 50N42 =
          # "general processing exception - unexpected error".
          DEFAULT_GQL_STATUS = '50N42'
          DEFAULT_STATUS_DESCRIPTION_PREFIX = 'error: general processing exception - unexpected error. '

          # Diagnostic-record classifications the spec recognises; anything else
          # (or absent) surfaces as the catch-all UNKNOWN.
          KNOWN_CLASSIFICATIONS = %w[CLIENT_ERROR DATABASE_ERROR TRANSIENT_ERROR].freeze

          attr_reader :metadata

          def initialize(metadata)
            @metadata = metadata
          end

          def code
            @metadata[:neo4j_code] || @metadata[:code]
          end

          def message
            @metadata[:message]
          end

          # Map this server FAILURE to its driver-side exception. Single owner of
          # the code→exception logic — used to live in 4+ places.
          def to_exception
            gql?(@metadata) ? build_gql(@metadata) : build_legacy(@metadata)
          end

          def accept(visitor)
            visitor.on_failure(self)
          end

          def assert_success!
            raise to_exception
          end

          def terminal? = true

          private

          def gql?(meta) = meta.key?(:gql_status)

          def exception_class(code)
            (EXCEPTION_FOR_CODE.find { |pattern, _| code.to_s.match?(pattern) }&.last if code) ||
              Exceptions::Neo4jException
          end

          # A handful of TransientError codes are non-retryable and surface
          # under their ClientError code (see CODE_REWRITES).
          def rewrite_code(code) = CODE_REWRITES[code] || code

          # Bolt 5.7+ GQL failure: read the fields straight off the wire, fill the
          # diagnostic-record defaults, and recurse into the cause chain.
          def build_gql(meta)
            diagnostic_record = fill_defaults(meta[:diagnostic_record])
            raw_classification = diagnostic_record[:_classification]
            raw_classification = nil unless raw_classification.is_a?(String)

            code = rewrite_code(meta[:neo4j_code])
            exception_class(code).new(
              meta[:message],
              code: code,
              gql_status: meta[:gql_status],
              status_description: meta[:description],
              diagnostic_record: diagnostic_record,
              raw_classification: raw_classification,
              classification: (raw_classification if KNOWN_CLASSIFICATIONS.include?(raw_classification)),
              gql_cause: meta[:cause] && build_gql(meta[:cause])
            )
          end

          # Legacy { code:, message: } failure — synthesise the GQL shape so the
          # exception carries the same fields a 5.7 server would have sent.
          def build_legacy(meta)
            code = rewrite_code(meta[:code])
            exception_class(code).new(
              meta[:message],
              code: code,
              gql_status: DEFAULT_GQL_STATUS,
              status_description: "#{DEFAULT_STATUS_DESCRIPTION_PREFIX}#{meta[:message]}",
              diagnostic_record: DEFAULT_DIAGNOSTIC_RECORD.dup
            )
          end

          def fill_defaults(record)
            DEFAULT_DIAGNOSTIC_RECORD.merge(record || {})
          end
        end
      end
    end
  end
end
