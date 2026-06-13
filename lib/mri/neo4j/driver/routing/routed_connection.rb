# frozen_string_literal: true

module Neo4j
  module Driver
    module Routing
      # Bolt::Connection wrapper that classifies routing-relevant
      # errors and feeds the routing table back. Mirrors Java's
      # RoutedBoltConnection + RoutingErrorHandler.onWriteFailure /
      # onConnectionFailure.
      #
      # The wrapper is a pure delegator on the read/write path — every
      # method is forwarded straight to the inner Bolt::Connection.
      # Classification doesn't happen on the wire-call boundary because
      # Bolt failures only become exceptions when the caller does
      # `.assert_success!` on the response (which raises outside the
      # delegator), and streaming failures only become exceptions when
      # Result's visitor dispatches to `on_failure`. Both of those call
      # sites — plus session.rb / transaction.rb's wire-error rescues —
      # invoke `classify_failure(error)` explicitly to run the side
      # effects (deactivate / on_write_failure) and get the
      # (possibly-swapped) exception to re-raise.
      class RoutedConnection
        extend Forwardable

        # Server-side error codes that indicate the connected node is no
        # longer the leader for the database we wrote to. Surface is
        # narrow on purpose — anything else (constraint violations,
        # syntax errors, etc.) is a user-facing failure that mustn't
        # invalidate the routing table.
        WRITE_FAILURE_CODES = %w[
          Neo.ClientError.Cluster.NotALeader
          Neo.ClientError.General.ForbiddenOnReadOnlyDatabase
        ].freeze

        DATABASE_UNAVAILABLE_CODE = 'Neo.TransientError.General.DatabaseUnavailable'

        attr_reader :inner, :address_obj
        attr_accessor :discard_on_release

        def initialize(pool, inner, address_obj, access_mode, database)
          @pool = pool
          @inner = inner
          @address_obj = address_obj
          @access_mode = access_mode
          @database = database
          @discard_on_release = false
        end

        def_delegators :@inner,
                       :address, :server_agent, :server_version, :protocol,
                       :closed?, :close, :pending_responses?,
                       :send_message, :send_all, :flush,
                       :fetch_response, :fetch_all,
                       :reset!, :route,
                       :auth, :driver_auth, :authenticate,
                       :auth_failed, :notify_security_exception

        # Run a caught exception through the routing classifier:
        # - ServiceUnavailableException → deactivate(address); mark
        #   the connection discardable; return the same exception.
        # - TransientException with DatabaseUnavailable → same.
        # - ClientException with NotALeader / ForbiddenOnReadOnly on
        #   a WRITE → on_write_failure(address, database); mark
        #   discardable; return a SessionExpiredException (so session
        #   retry catches it) with the original error code preserved.
        # - Anything else → return the same exception unchanged.
        #
        # Callers: session.rb (RUN-response rescue), transaction.rb
        # (BEGIN/RUN/COMMIT rescues), Result#on_failure (streaming
        # PULL/DISCARD). Each invokes this in its catch-Neo4jException
        # block and re-raises whatever we return.
        def classify_failure(error)
          # Funnel security failures to the auth-token manager first (via
          # the inner connection's provider-set handler); a retryable one
          # comes back wrapped as SecurityRetryableException. Then apply
          # routing classification to whatever we surface.
          error = @inner.notify_security_exception(error)
          # A security failure compromises the connection (server closes
          # it; identity is bad) — discard regardless of routing role.
          @discard_on_release = true if error.is_a?(Exceptions::SecurityException)

          case error
          when Exceptions::SessionExpiredException
            # Already routing-classified — deactivate and keep the type.
            @discard_on_release = true
            @pool.deactivate(@address_obj)
            error
          when Exceptions::ServiceUnavailableException
            @discard_on_release = true
            @pool.deactivate(@address_obj)
            # In routing, a dead connection means this server can no longer
            # serve the session — surface as SessionExpired so managed-tx
            # retry picks a different server (mirrors Java's RoutingConnection
            # mapping connection failures to SessionExpired). Both are
            # retryable, so retry behaviour is unchanged; only the surfaced
            # type differs. The original is chained as `cause` automatically
            # when the caller re-raises this inside its `rescue => error`.
            Exceptions::SessionExpiredException.new(error.message, code: error.code)
          when Exceptions::TransientException
            if error.code == DATABASE_UNAVAILABLE_CODE
              @discard_on_release = true
              @pool.deactivate(@address_obj)
            end
            error
          when Exceptions::ClientException
            if @access_mode == :write && WRITE_FAILURE_CODES.include?(error.code)
              @discard_on_release = true
              @pool.on_write_failure(@address_obj, @database)
              # Original ClientException chained as `cause` at re-raise.
              Exceptions::SessionExpiredException.new(
                "Server at #{@address_obj} no longer accepts writes for database " \
                "#{@database.inspect} (#{error.code})",
                code: error.code
              )
            else
              error
            end
          else
            error
          end
        end
      end
    end
  end
end
