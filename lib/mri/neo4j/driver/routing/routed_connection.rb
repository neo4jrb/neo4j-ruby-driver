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
                       :reset!, :route

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
          case error
          when Exceptions::ServiceUnavailableException
            @discard_on_release = true
            @pool.deactivate(@address_obj)
            error
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
              Exceptions::SessionExpiredException.new(
                "Server at #{@address_obj} no longer accepts writes for database " \
                "#{@database.inspect} (#{error.code})",
                code: error.code,
                suppressed: [error]
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
