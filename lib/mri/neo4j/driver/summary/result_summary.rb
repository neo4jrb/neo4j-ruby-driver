# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # Summary of query execution. Mirrors Java's
      # org.neo4j.driver.summary.ResultSummary — same name and place in
      # the namespace; no public `metadata` accessor, no Bolt-wire-format
      # leakage.
      class ResultSummary
        def initialize(metadata, query_text = nil, parameters = {}, connection = nil)
          @metadata = metadata
          @query_text = query_text
          @parameters = parameters
          @connection = connection
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

        # GQL status objects, as reported natively by Bolt 5.6+ servers in
        # the summary `statuses` list (preserving server order — the driver
        # must not reorder them). A status carrying a `neo4j_code` is also a
        # notification (GqlNotification); the rest are plain status objects.
        # The pre-5.6 backfill (Feature:API:Summary:GqlStatusObjects, which
        # synthesises statuses from notifications) isn't implemented, so it
        # stays unadvertised.
        def gql_status_objects
          (@metadata[:statuses] || []).map do |status|
            (status[:neo4j_code] ? GqlNotification : GqlStatusObject).new(status)
          end
        end

        private

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
