# frozen_string_literal: true

module Neo4j
  module Driver
    module Routing
      # Bolt::Connection wrapper that classifies errors and feeds the
      # routing table back. Mirrors Java's RoutedBoltConnection +
      # RoutingErrorHandler.onWriteFailure / onConnectionFailure.
      #
      # The wrapper is opaque to Session/Transaction/Result — every
      # method that exists on Bolt::Connection and is called from those
      # callers is forwarded here; everything else is exposed via the
      # `inner` accessor for LoadBalancer's own release path.
      class RoutedConnection
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

        # --- Pure forwards (can't raise classifiable errors) -----------

        def address        = @inner.address
        def server_agent   = @inner.server_agent
        def server_version = @inner.server_version
        def protocol       = @inner.protocol
        def closed?        = @inner.closed?
        def close          = @inner.close
        def pending_responses? = @inner.pending_responses?

        # --- Error-classifying forwards --------------------------------

        def send_message(message)
          with_error_handling { @inner.send_message(message) }
        end

        def send_all(*messages)
          with_error_handling { @inner.send_all(*messages) }
        end

        def flush
          with_error_handling { @inner.flush }
        end

        def fetch_response
          with_error_handling { @inner.fetch_response }
        end

        # Run a caught exception through the same classify-and-side-effect
        # chain that wraps wire calls, then return what to re-raise.
        # Callers use this when the FAILURE response is detected outside
        # the wrapper — e.g. session.rb's `fetch_response.assert_success!`
        # raises after fetch_response returned a Failure, and Result's
        # visitor dispatches to on_failure which then raises. Both go
        # through this so on_write_failure / deactivate fire, and the
        # exception class is swapped where appropriate.
        def classify_failure(error)
          with_error_handling { raise error }
        rescue StandardError => classified
          classified
        end

        def fetch_all
          with_error_handling { @inner.fetch_all }
        end

        def reset!
          with_error_handling { @inner.reset! }
        end

        def route(**kwargs)
          with_error_handling { @inner.route(**kwargs) }
        end

        private

        def with_error_handling
          yield
        rescue Exceptions::ServiceUnavailableException
          # Server is unreachable: evict from every routing table and
          # tear down the per-server pool. The session-level retry will
          # acquire a fresh connection from another address.
          @discard_on_release = true
          @pool.deactivate(@address_obj)
          raise
        rescue Exceptions::TransientException => e
          # DatabaseUnavailable is the only transient error that should
          # actually invalidate the server — the database has gone away
          # there. Other transients (deadlocks, etc.) are retry-on-same.
          if e.code == DATABASE_UNAVAILABLE_CODE
            @discard_on_release = true
            @pool.deactivate(@address_obj)
          end
          raise
        rescue Exceptions::ClientException => e
          # NotALeader / ForbiddenOnReadOnlyDatabase on a WRITE means the
          # connected server is alive but no longer the writer for this
          # db. Evict from writers only and re-raise as SessionExpired so
          # the session-level retry path picks it up.
          if @access_mode == :write && WRITE_FAILURE_CODES.include?(e.code)
            # Connection is in server-FAILED state after a write failure;
            # discard rather than push back, so the next acquire builds
            # a fresh one against whichever server takes over as writer.
            @discard_on_release = true
            @pool.on_write_failure(@address_obj, @database)
            raise Exceptions::SessionExpiredException.new(
              "Server at #{@address_obj} no longer accepts writes for database " \
              "#{@database.inspect} (#{e.code})",
              code: e.code,
              suppressed: [e]
            )
          end
          raise
        end
      end
    end
  end
end
