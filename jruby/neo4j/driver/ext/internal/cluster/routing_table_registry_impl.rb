# frozen_string_literal: true

module Neo4j::Driver::Ext
  module Internal
    module Cluster
      module RoutingTableRegistryImpl
        def routing_table_handler(database)
          get_routing_table_handler(org.neo4j.driver.internal.DatabaseNameUtil.database(database)).then do |it|
            it.get if it.present?
          end
        end
      end
    end
  end
end
