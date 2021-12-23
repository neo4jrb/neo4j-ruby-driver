module Neo4j::Driver::Internal::Summary
  class InternalSummaryCounters < Struct.new(:nodes_created, :nodes_deleted, :relationships_created, :relationships_deleted, :properties_set, :labels_added, :labels_removed, :indexes_added, :indexes_removed, :constraints_added, :constraints_removed, :system_updates)
    EMPTY_STATS = InternalSummaryCounters.new(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

    def contains_updates?
      any?(&:positive?)
    end

    def contains_system_updates?
      system_updates.positive?
    end

    def to_s
      "InternalSummaryCounters{" +
      "nodes_created=#{nodes_created}"\
      ", nodes_deleted=#{nodes_deleted}"\
      ", relationships_created=#{relationships_created}"\
      ", relationships_deleted=#{relationships_deleted}"\
      ", properties_set=#{properties_set}"\
      ", labels_added=#{labels_added}"\
      ", labels_removed=#{labels_removed}"\
      ", indexes_added=#{indexes_added}"\
      ", indexes_removed=#{indexes_removed}"\
      ", constraints_added=#{constraints_added}"\
      ", constraints_removed=#{constraints_removed}"\
      ", system_updates=#{system_updates}"\
      "}"
    end
  end
end
