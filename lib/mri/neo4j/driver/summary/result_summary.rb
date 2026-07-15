# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # Summary of query execution. Mirrors Java's
      # org.neo4j.driver.summary.ResultSummary — same name and place in
      # the namespace; no public `metadata` accessor, no Bolt-wire-format
      # leakage.
      class ResultSummary
        def initialize(metadata, query_text = nil, parameters = {}, connection = nil, had_record: false)
          @metadata = metadata
          @query_text = query_text
          @parameters = parameters
          @connection = connection
          @had_record = had_record
        end

        def query
          Query.new(@query_text, @parameters)
        end

        # Mirrors Java's ResultSummary#queryType — returns nil only when the
        # server omitted the :type field (testkit relies on this). A field
        # that is present but holds anything other than a known code — an
        # unrecognised string, or an explicit null — is a protocol
        # violation, so we raise (Java's extractQueryType chokes on those
        # too) rather than silently returning nil.
        def query_type
          return nil unless @metadata.key?(:type)

          case @metadata[:type]
          when 'r' then QueryType::READ_ONLY
          when 'w' then QueryType::WRITE_ONLY
          when 'rw' then QueryType::READ_WRITE
          when 's' then QueryType::SCHEMA_WRITE
          else
            raise Exceptions::ProtocolException, "Unexpected query type: #{@metadata[:type].inspect}"
          end
        end

        def counters
          @counters ||= SummaryCounters.new(@metadata[:stats] || {})
        end

        def server
          @server_info ||=
            if @metadata[:server]
              ServerInfo.new(@metadata[:server])
            elsif @connection
              ServerInfo.new(
                address: @connection.address,
                agent: @connection.server_agent,
                protocol_version: @connection.protocol&.version
              )
            else
              ServerInfo.new(nil)
            end
        end

        def database
          @database_info ||= DatabaseInfo.new(@metadata[:db])
        end

        # Time until results are available (milliseconds). 't_first' on the wire.
        def result_available_after
          @metadata[:t_first]
        end

        # Time to consume results (milliseconds). 't_last' on the wire.
        def result_consumed_after
          @metadata[:t_last]
        end

        def plan
          return @plan if defined?(@plan)
          @plan =
            if @metadata[:plan]
              Plan.new(@metadata[:plan])
            elsif @metadata[:profile]
              # Profile is a superset of plan — return the same object.
              profile
            end
        end

        def profile
          return @profile if defined?(@profile)
          @profile = @metadata[:profile] ? Profile.new(@metadata[:profile]) : nil
        end

        def has_plan?
          !@metadata[:plan].nil? || !@metadata[:profile].nil?
        end

        def has_profile?
          !@metadata[:profile].nil?
        end

        # Bolt 5.5+ servers report query info via `statuses` (GQL status
        # objects) rather than the legacy `notifications` list. Statuses
        # without a `neo4j_code` are pure-GQL info (e.g. "successful
        # completion") and have no legacy-notification equivalent, so we
        # drop them; the rest are reshaped to look like `notifications`.
        def notifications
          (@metadata[:notifications] || statuses_as_notifications)
            .map { |n| Notification.new(n) }
        end

        # GQL status objects. Bolt 5.6+ servers report them natively in the
        # summary `statuses` list, which we preserve verbatim (server order —
        # the driver must not reorder them). Older servers (or any SUCCESS
        # without `statuses`) don't, so we synthesise the list from the legacy
        # `notifications` plus a mandatory outcome status — the pre-5.6
        # backfill. A status carrying a `neo4j_code` is also a notification
        # (GqlNotification); the rest are plain status objects.
        def gql_status_objects
          (@metadata[:statuses] || polyfilled_statuses).map do |status|
            (status[:neo4j_code] ? GqlNotification : GqlStatusObject).new(status)
          end
        end

        private

        # Synthesise `statuses` from the legacy `notifications` list plus a
        # single outcome status, mirroring the Java driver's MetadataExtractor.
        # The whole set is ordered by GQL status class (02 no-data, 01 warning,
        # 00 success, 03 info, then everything else); the sort is stable so
        # same-class notifications keep their server order.
        def polyfilled_statuses
          statuses = (@metadata[:notifications] || []).map { notification_as_status(it) }
          statuses << outcome_status
          statuses.each_with_index.sort_by { |status, i| [gql_status_class(status), i] }.map(&:first)
        end

        # The mandatory outcome status. The driver reached the summary having
        # streamed the whole result (eager pull), so it knows whether a record
        # arrived: yes -> successful completion; no -> "no data", or "omitted
        # result" when the query produced no fields at all (e.g. a write).
        def outcome_status
          if @had_record
            { gql_status: '00000', status_description: 'note: successful completion' }
          elsif Array(@metadata[:fields]).empty?
            { gql_status: '00001', status_description: 'note: successful completion - omitted result' }
          else
            { gql_status: '02000', status_description: 'note: no data' }
          end
        end

        # Reshape one legacy notification into a `statuses`-list entry so it
        # flows through GqlNotification unchanged. WARNING -> 01N42, everything
        # else -> 03N42; the notification facets move into the diagnostic
        # record under `_severity` / `_classification` / `_position`.
        def notification_as_status(notification)
          # Old wire format carries :severity, newer :severityLevel — read both,
          # matching Summary::Notification.
          severity = notification[:severityLevel] || notification[:severity]
          warning = severity == 'WARNING'
          description = notification[:description] unless notification[:description] == 'null'
          {
            gql_status: warning ? '01N42' : '03N42',
            status_description: description || (warning ? 'warn: unknown warning' : 'info: unknown notification'),
            neo4j_code: notification[:code],
            title: notification[:title],
            diagnostic_record: { _severity: severity, _classification: notification[:category],
                                 _position: notification[:position] }.compact
          }
        end

        # Sort key from the GQL status class (first two chars of the code).
        def gql_status_class(status)
          case status[:gql_status]
          when /\A02/ then 0
          when /\A01/ then 1
          when /\A00/ then 2
          when /\A03/ then 3
          else 4
          end
        end

        def statuses_as_notifications
          (@metadata[:statuses] || []).filter_map do |s|
            next unless s[:neo4j_code]

            dr = s[:diagnostic_record] || {}
            {
              code: s[:neo4j_code],
              title: s[:title],
              description: s[:description],
              severity: dr[:_severity],
              category: dr[:_classification],
              position: dr[:_position]
            }.compact
          end
        end

        # Internal-only accessor. NOT part of the public API — Java's
        # ResultSummary doesn't expose the raw wire metadata either. The
        # one in-tree consumer is Session#harvest_auto_commit_bookmark
        # (which reaches in via send) because the auto-commit bookmark
        # only ever lives on the wire SUCCESS metadata.
        attr_reader :metadata
      end
    end
  end
end
