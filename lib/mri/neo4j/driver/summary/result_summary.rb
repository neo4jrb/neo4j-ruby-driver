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

        def query_type
          case @metadata[:type]
          when 'r' then QueryType::READ_ONLY
          when 'w' then QueryType::WRITE_ONLY
          when 'rw' then QueryType::READ_WRITE
          when 's' then QueryType::SCHEMA_WRITE
          else QueryType::READ_ONLY
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

        def notifications
          (@metadata[:notifications] || []).map { |n| Notification.new(n) }
        end

        private

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
