# frozen_string_literal: true

module TestkitBackend
  # Response value objects. Each subclass is a `Data.define(...)` whose
  # members become the JSON `data` payload, with snake_case → camelCase
  # conversion handled by the shared mixin.
  #
  # Override #payload when the default (camelize members → hash) doesn't fit.
  #
  # Coverage maps onto testkit's nutkit/protocol/responses.py (48 classes).
  # See TESTKIT.md for the per-handler/response coverage table.
  module Response
    module Mixin
      # Default JSON `name` is the unqualified class name.
      def name
        self.class.name.split('::').last
      end

      # Default `data` payload: members serialised with camelCase keys.
      def payload
        members.each_with_object({}) { |m, acc| acc[Casing.camel(m)] = public_send(m) }
      end

      # Frame to ship over the testkit wire.
      def to_payload
        { 'name' => name, 'data' => payload }
      end
    end

    # ─────────────────────────────────────────────────────── Test orchestration

    # Response to StartTest — backend confirms the test should run.
    class RunTest < Data.define
      include Mixin
    end

    # Response to StartTest — backend wants to opt in/out per subtest.
    # Testkit will then send a StartSubTest for each subtest.
    class RunSubTests < Data.define
      include Mixin
    end

    # Response to StartTest / StartSubTest — backend wants the test skipped.
    class SkipTest < Data.define(:reason)
      include Mixin
    end

    # Response to GetFeatures — list of advertised feature flag strings.
    class FeatureList < Data.define(:features)
      include Mixin
    end

    # ────────────────────────────────────────────────────────── Driver lifecycle

    class Driver < Data.define(:id)
      include Mixin
    end

    # ──────────────────────────────────────────── Auth token managers (B-stubs)

    class AuthTokenManager < Data.define(:id)
      include Mixin
    end

    # Sent FROM backend asking the test to call its provider function and
    # respond with AuthTokenManagerGetAuthCompleted.
    class AuthTokenManagerGetAuthRequest < Data.define(:id, :auth_token_manager_id)
      include Mixin
    end

    # Sent FROM backend when the driver wants to notify the manager of a
    # security exception. Test responds with
    # AuthTokenManagerHandleSecurityExceptionRequestCompleted.
    class AuthTokenManagerHandleSecurityExceptionRequest <
          Data.define(:id, :auth_token_manager_id, :auth, :error_code)
      include Mixin
    end

    class BasicAuthTokenManager < Data.define(:id)
      include Mixin
    end

    class BasicAuthTokenProviderRequest < Data.define(:id, :basic_auth_token_manager_id)
      include Mixin
    end

    class BearerAuthTokenManager < Data.define(:id)
      include Mixin
    end

    class BearerAuthTokenProviderRequest < Data.define(:id, :bearer_auth_token_manager_id)
      include Mixin
    end

    # ────────────────────────────────────────────────── Client cert (B-stub)

    class ClientCertificateProvider < Data.define(:id)
      include Mixin
    end

    class ClientCertificateProviderRequest < Data.define(:id, :client_certificate_provider_id)
      include Mixin
    end

    # ────────────────────────────────────────────────── Resolver / DNS callbacks

    # Sent FROM backend when the driver's custom resolver fires; the test
    # responds with ResolverResolutionCompleted carrying resolved addresses.
    class ResolverResolutionRequired < Data.define(:id, :address)
      include Mixin
    end

    # Sent FROM backend when the driver's domain-name resolver fires.
    class DomainNameResolutionRequired < Data.define(:id, :name)
      include Mixin
    end

    # ─────────────────────────────────────────────────── Bookmark manager (B-stub)

    class BookmarkManager < Data.define(:id)
      include Mixin
    end

    class BookmarksSupplierRequest < Data.define(:id, :bookmark_manager_id)
      include Mixin
    end

    class BookmarksConsumerRequest < Data.define(:id, :bookmark_manager_id, :bookmarks)
      include Mixin
    end

    # ─────────────────────────────────────────────────────── Driver capabilities

    class MultiDBSupport < Data.define(:id, :available)
      include Mixin
    end

    class DriverIsAuthenticated < Data.define(:id, :authenticated)
      include Mixin
    end

    class SessionAuthSupport < Data.define(:id, :available)
      include Mixin
    end

    class DriverIsEncrypted < Data.define(:encrypted)
      include Mixin
    end

    # ─────────────────────────────────────────────────────────── Session / tx / result

    class Session < Data.define(:id)
      include Mixin
    end

    class Transaction < Data.define(:id)
      include Mixin
    end

    class Result < Data.define(:id, :keys)
      include Mixin
    end

    class Record < Data.define(:values)
      include Mixin

      def self.from_driver_record(record)
        new(values: record.values.map(&Cypher.method(:from_ruby)))
      end
    end

    # A single value extracted from a record (response to CypherTypeField).
    class Field < Data.define(:value)
      include Mixin
    end

    class NullRecord < Data.define
      include Mixin
    end

    class RecordList < Data.define(:records)
      include Mixin
    end

    # Response to ResultSingleOptional. `record` is nil-or-Record, `warnings`
    # is a list of strings.
    class RecordOptional < Data.define(:record, :warnings)
      include Mixin
    end

    class Bookmarks < Data.define(:bookmarks)
      include Mixin
    end

    # ─────────────────────────────────────────────────────── Managed transaction

    # Sent during a SessionReadTransaction / SessionWriteTransaction's
    # nested loop, to tell testkit "I've started a tx, here's its id".
    # `id` is the transaction id testkit will operate against until it
    # sends RetryablePositive / RetryableNegative.
    class RetryableTry < Data.define(:id)
      include Mixin
    end

    # Closes out a successful managed-transaction handler after the
    # driver commits. Carries no payload.
    class RetryableDone < Data.define
      include Mixin
    end

    # ──────────────────────────────────────────────── Summary (rich nested types)

    # Custom payload shape: the existing Summary subclass builds the hash
    # itself rather than relying on the default member→camelCase map. Kept
    # for backward compat with the populated payloads in `summary_payload.rb`;
    # nested helper classes below are for new code paths.
    class Summary
      include Mixin

      def initialize(payload)
        @payload = payload
      end

      def payload
        @payload
      end
    end

    class ServerInfo < Data.define(:address, :agent, :protocol_version)
      include Mixin
    end

    class SummaryCounters < Data.define(
      :constraints_added, :constraints_removed,
      :contains_system_updates, :contains_updates,
      :indexes_added, :indexes_removed,
      :labels_added, :labels_removed,
      :nodes_created, :nodes_deleted,
      :properties_set,
      :relationships_created, :relationships_deleted,
      :system_updates
    )
      include Mixin
    end

    class SummaryQuery < Data.define(:text, :parameters)
      include Mixin
    end

    # Per testkit: gqlStatus/statusDescription/classification/severity are
    # required strings; rawClassification/rawSeverity may be nil; position
    # is nil or {column, line, offset}; diagnosticRecord is a dict;
    # isNotification is a bool.
    class GqlStatusObject < Data.define(
      :gql_status, :status_description, :position,
      :classification, :raw_classification,
      :severity, :raw_severity,
      :diagnostic_record, :is_notification
    )
      include Mixin
    end

    # ──────────────────────────────────────────────────── Routing / pool / metrics

    class RoutingTable < Data.define(:database, :ttl, :routers, :readers, :writers)
      include Mixin
    end

    class ConnectionPoolMetrics < Data.define(:in_use, :idle)
      include Mixin
    end

    # ───────────────────────────────────────────────────────── ExecuteQuery

    class EagerResult < Data.define(:keys, :records, :summary)
      include Mixin
    end

    # ───────────────────────────────────────────────────────── Fake-time

    class FakeTimeAck < Data.define
      include Mixin
    end

    # ──────────────────────────────────────────────────────────── Errors

    class DriverError < Data.define(
      :id, :error_type, :code, :msg, :retryable,
      :gql_status, :status_description,
      :cause, :diagnostic_record,
      :classification, :raw_classification
    )
      include Mixin

      # Used by stub handlers (categories B and C in TESTKIT.md): tells
      # testkit "the driver doesn't support this yet." `code: 'NotImplemented'`
      # is the convention; testkit treats it as a normal driver-thrown
      # error and the test will fail (or skip if it's gated on a feature
      # we don't advertise).
      def self.not_implemented(msg)
        new(
          id: nil,
          error_type: 'NotImplementedError',
          code: 'NotImplemented',
          msg: msg,
          retryable: false,
          gql_status: nil, status_description: nil,
          cause: nil, diagnostic_record: nil,
          classification: nil, raw_classification: nil
        )
      end

      # Stash the exception in the registry under the same id we hand
      # to testkit — RetryableNegative will look it up and re-raise.
      def self.from(exception, registry:)
        id = registry.store(exception, prefix: 'error')
        new(
          id: id,
          error_type: exception.class.name,
          code: exception.respond_to?(:code) ? exception.code : nil,
          msg: exception.message,
          retryable: exception.is_a?(Neo4j::Driver::Exceptions::TransientException),
          gql_status: nil, status_description: nil,
          cause: nil, diagnostic_record: nil,
          classification: nil, raw_classification: nil
        )
      end
    end

    # Nested type used as DriverError#cause. Mirrors testkit's GqlError.
    class GqlError < Data.define(
      :msg, :gql_status, :status_description,
      :cause, :diagnostic_record,
      :classification, :raw_classification
    )
      include Mixin
    end

    class FrontendError < Data.define(:msg)
      include Mixin
    end

    class BackendError < Data.define(:msg)
      include Mixin
    end

    # Backend-internal: returned when dispatch encounters a request name
    # that doesn't map to any handler class. Kept for graceful protocol
    # evolution; testkit treats unknown response names as test failures.
    class UnknownType < Data.define(:message)
      include Mixin

      def name
        'UnknownTypeError'
      end
    end
  end
end
