# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Base of the per-minor protocol class hierarchy. Mirrors Java's
        # BoltProtocolVxY family in `neo4j-bolt-connection-java` — each
        # minor version is its own subclass and only overrides what
        # changed at that version, instead of carrying a swarm of
        # `version >= V5_X` checks inside one big class.
        class Base
          attr_reader :version, :connection

          def initialize(connection, version)
            @connection = connection
            @version = version
          end

          # Top-level HELLO builder. The shape is fixed (one map argument);
          # subclasses override `hello_extra` to change which keys it
          # carries at their version. `notification_config` (the driver's
          # NotificationsConfig, a `{minimum_severity:, disabled_categories:}`
          # hash or nil) only lands on the wire from V52 on — older versions
          # return an empty map from `notification_config_extra`.
          def build_hello_message(user_agent:, auth:, routing: nil, notification_config: nil)
            extra = hello_extra(user_agent:, auth:, routing:)
                    .merge(notification_config_extra(notification_config))
            PackStream::Structure.new(Message::HELLO, [extra.compact])
          end

          # Subclasses override this to add / remove fields from the
          # HELLO map. The defaults here are deliberately empty; V4 is
          # the first concrete protocol that fills them in.
          def hello_extra(user_agent:, auth:, routing:)
            raise NotImplementedError, "#{self.class} must implement hello_extra"
          end

          # Notification-filtering keys for the HELLO map. Empty until V52,
          # the first version whose server honours them (V52 overrides this).
          def notification_config_extra(_notification_config) = {}

          # Hook for V51+ (HELLO/LOGON split): the LOGON message the connection
          # pipelines right after HELLO. nil here — older versions carry auth in
          # the HELLO map and send no separate LOGON.
          def build_logon_message(_auth) = nil

          # Hook for V5+: lets the protocol flip the packer's UTC
          # datetime flag (0x49 / 0x69 vs legacy 0x46 / 0x66).
          def configure_packer(_packer); end

          # Hook for per-version unpacker customisation — re-registering
          # handlers for messages whose shape changed at this version
          # (V57 FAILURE) or adding handlers for new struct types
          # (V6 VECTOR / UNSUPPORTED). Called after Connection
          # registers the common ones, so an override here wins.
          def customize_hydration(_unpacker); end

          # --- Message builders -------------------------------------------
          # The protocol handler owns the wire shape of the streaming /
          # transaction messages, mirroring Java's BoltProtocolVxY. The
          # defaults here are the Bolt 4.0+ forms; V3 overrides the three
          # that changed: PULL/DISCARD carry no fields, and RUN/BEGIN have
          # no `db` (3.0 is single-database). The `db` strip is keyed on
          # supports_multiple_databases? so it is automatic for V3.

          def build_run(query, parameters, extra)
            enforce_impersonation_support!(extra[:imp_user])
            Message.run(query, parameters, strip_db(extra))
          end

          def build_begin(extra)
            enforce_impersonation_support!(extra[:imp_user])
            Message.begin_transaction(strip_db(extra))
          end

          # 4.0+ PULL carries `{n, qid}`. V3 overrides to the
          # parameterless PULL_ALL.
          def build_pull(extra)
            Message.pull(extra)
          end

          # 4.0+ DISCARD carries `{n, qid}`. V3 overrides to DISCARD_ALL.
          def build_discard(extra)
            Message.discard(extra)
          end

          def build_telemetry(api)
            Message.telemetry(api)
          end

          def supports_re_auth? = false
          def supports_multiple_databases? = false
          def supports_notification_filtering? = false
          # TELEMETRY (driver-API usage reporting) arrived with Bolt 5.4;
          # V54 flips this to true.
          def supports_telemetry? = false
          # Impersonation (imp_user on RUN/BEGIN/ROUTE) arrived with Bolt 4.4;
          # V44 flips this to true.
          def supports_impersonation? = false

          # Fail fast when a caller asks to impersonate over a protocol
          # that can't carry imp_user (Bolt < 4.4) — otherwise the field
          # is silently dropped and the query runs as the authenticated
          # user. Matches Java, which raises ClientException here. Public
          # so Connection#route can enforce the same rule on the discovery
          # path (a routed session impersonating against a 4.3 cluster
          # must fail before sending ROUTE, not silently lose imp_user).
          def enforce_impersonation_support!(imp_user)
            return if imp_user.nil? || supports_impersonation?

            raise Exceptions::ClientException,
                  "Impersonation (impersonated_user) is not supported on Bolt #{version}; requires Bolt 4.4+"
          end

          private

          def strip_db(extra)
            return extra if supports_multiple_databases?

            extra.reject { |key, _| key.to_sym == :db }
          end
        end
      end
    end
  end
end
