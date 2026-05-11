# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # Per-operation counts produced by the query.
      # Mirrors org.neo4j.driver.summary.SummaryCounters.
      class SummaryCounters
        attr_reader :nodes_created, :nodes_deleted,
                    :relationships_created, :relationships_deleted,
                    :properties_set,
                    :labels_added, :labels_removed,
                    :indexes_added, :indexes_removed,
                    :constraints_added, :constraints_removed,
                    :system_updates

        # Mapping from server metadata keys (kebab-case strings sent on the
        # wire as Symbols) to Ruby attribute names.
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
          # Initialize all counters to 0 — server only reports nonzero ones.
          COUNTER_KEYS.each_value { |attr| instance_variable_set("@#{attr}", 0) }

          stats.each do |key, value|
            attr_name = COUNTER_KEYS[key]
            instance_variable_set("@#{attr_name}", value.to_i) if attr_name
          end
        end

        def contains_updates?
          nodes_created.positive? ||
            nodes_deleted.positive? ||
            relationships_created.positive? ||
            relationships_deleted.positive? ||
            properties_set.positive? ||
            labels_added.positive? ||
            labels_removed.positive? ||
            indexes_added.positive? ||
            indexes_removed.positive? ||
            constraints_added.positive? ||
            constraints_removed.positive?
        end

        def contains_system_updates?
          system_updates.positive?
        end

        def to_h
          COUNTER_KEYS.values.to_h { |attr| [attr, instance_variable_get("@#{attr}")] }
        end

        def to_s
          to_h.select { |_, v| v.positive? }.map { |k, v| "#{k}: #{v}" }.join(', ')
        end
      end
    end
  end
end
