# frozen_string_literal: true

module Neo4j
  module Driver
    # Summary of result execution
    class Summary
      attr_reader :metadata

      def initialize(metadata, query_text = nil, parameters = {}, connection = nil)
        @metadata = metadata
        @query_text = query_text
        @parameters = parameters
        @connection = connection
        @counters = nil
        @server_info = nil
        @database_info = nil
      end

      def query
        Query.new(@query_text, @parameters)
      end

      def query_type
        type_str = @metadata[:type]
        case type_str
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
        @server_info ||= begin
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
      end

      def database
        @database_info ||= DatabaseInfo.new(@metadata[:db])
      end

      def result_available_after
        # t_first is time until results are available (milliseconds)
        @metadata[:t_first]
      end

      def result_consumed_after
        # t_last is time to consume results (milliseconds)
        @metadata[:t_last]
      end

      def plan
        return @plan if defined?(@plan)
        if @metadata[:plan]
          @plan = Plan.new(@metadata[:plan])
        elsif @metadata[:profile]
          # Profile is a superset of plan, return the same object
          @plan = profile
        else
          @plan = nil
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

      module QueryType
        READ_ONLY = :read_only
        WRITE_ONLY = :write_only
        READ_WRITE = :read_write
        SCHEMA_WRITE = :schema_write
      end

      class Query
        attr_reader :text, :parameters

        def initialize(text, parameters = {})
          @text = text
          @parameters = parameters
        end
      end

      # Information about the server where the result originated
      class ServerInfo
        attr_reader :address, :agent, :protocol_version

        def initialize(server_data = nil, address: nil, agent: nil, protocol_version: nil)
          if server_data.is_a?(String)
            @agent = server_data
            @address = address
            @protocol_version = protocol_version
          elsif server_data.is_a?(Hash)
            @address = server_data[:address] || address
            @agent = server_data[:agent] || agent
            @protocol_version = server_data[:protocol_version] || protocol_version
          else
            @address = address
            @agent = agent
            @protocol_version = protocol_version
          end
        end

        def to_s
          @agent || 'Unknown'
        end
      end

      # Information about the database where the result originated
      class DatabaseInfo
        attr_reader :name

        def initialize(db_data)
          if db_data.is_a?(String)
            @name = db_data
          elsif db_data.is_a?(Hash)
            @name = db_data[:name]
          else
            @name = nil
          end
        end

        def to_s
          @name || 'unknown'
        end
      end

      # Counters for operations triggered by the query
      class SummaryCounters
        attr_reader :nodes_created, :nodes_deleted,
                    :relationships_created, :relationships_deleted,
                    :properties_set,
                    :labels_added, :labels_removed,
                    :indexes_added, :indexes_removed,
                    :constraints_added, :constraints_removed,
                    :system_updates

        # Mapping from server metadata keys to Ruby attribute names
        COUNTER_KEYS = {
          'nodes-created': :nodes_created,
          'nodes-deleted': :nodes_deleted,
          'relationships-created': :relationships_created,
          'relationships-deleted': :relationships_deleted,
          'properties-set': :properties_set,
          'labels-added': :labels_added,
          'labels-removed': :labels_removed,
          'indexes-added': :indexes_added,
          'indexes-removed': :indexes_removed,
          'constraints-added': :constraints_added,
          'constraints-removed': :constraints_removed,
          'system-updates': :system_updates
        }.freeze

        def initialize(stats)
          # Initialize all counters to 0
          @nodes_created = 0
          @nodes_deleted = 0
          @relationships_created = 0
          @relationships_deleted = 0
          @properties_set = 0
          @labels_added = 0
          @labels_removed = 0
          @indexes_added = 0
          @indexes_removed = 0
          @constraints_added = 0
          @constraints_removed = 0
          @system_updates = 0

          # Parse stats from metadata
          stats.each do |key, value|
            attr_name = COUNTER_KEYS[key]
            instance_variable_set("@#{attr_name}", value.to_i) if attr_name
          end
        end

        def contains_updates?
          nodes_created > 0 ||
            nodes_deleted > 0 ||
            relationships_created > 0 ||
            relationships_deleted > 0 ||
            properties_set > 0 ||
            labels_added > 0 ||
            labels_removed > 0 ||
            indexes_added > 0 ||
            indexes_removed > 0 ||
            constraints_added > 0 ||
            constraints_removed > 0
        end

        def contains_system_updates?
          system_updates > 0
        end

        def to_h
          {
            nodes_created: @nodes_created,
            nodes_deleted: @nodes_deleted,
            relationships_created: @relationships_created,
            relationships_deleted: @relationships_deleted,
            properties_set: @properties_set,
            labels_added: @labels_added,
            labels_removed: @labels_removed,
            indexes_added: @indexes_added,
            indexes_removed: @indexes_removed,
            constraints_added: @constraints_added,
            constraints_removed: @constraints_removed,
            system_updates: @system_updates
          }
        end

        def to_s
          to_h.select { |_, v| v > 0 }.map { |k, v| "#{k}: #{v}" }.join(', ')
        end
      end

      # Query execution plan
      class Plan
        attr_reader :operator_type, :identifiers, :arguments, :children

        def initialize(plan_data)
          @operator_type = plan_data[:operatorType] || plan_data[:'operatorType']
          @identifiers = plan_data[:identifiers] || []
          @arguments = plan_data[:args] || {}
          @children = (plan_data[:children] || []).map { |child| Plan.new(child) }
        end
      end

      # Query execution profile (includes plan + execution stats)
      class Profile < Plan
        attr_reader :db_hits, :records, :rows

        def initialize(profile_data)
          super(profile_data)
          @db_hits = profile_data[:dbHits] || profile_data[:'dbHits'] || 0
          @records = profile_data[:rows] || profile_data[:records] || 0
          @rows = @records
        end
      end

      # Notification about query execution
      class Notification
        attr_reader :code, :title, :description, :severity_level, :severity, :category, :position

        def initialize(notification_data)
          @code = notification_data[:code]
          @title = notification_data[:title]
          @description = notification_data[:description]
          # Try various formats of severity keys
          @severity_level = notification_data[:severityLevel] ||
                           notification_data[:'severityLevel'] ||
                           notification_data[:severity]
          @severity = @severity_level
          @category = notification_data[:category]
          @position = notification_data[:position] ? Position.new(notification_data[:position]) : nil
        end

        # Position in the query where the notification applies
        class Position
          attr_reader :offset, :line, :column

          def initialize(position_data)
            @offset = position_data[:offset]
            @line = position_data[:line]
            @column = position_data[:column]
          end
        end
      end
    end
  end
end
