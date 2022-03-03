# frozen_string_literal: true

module Neo4j::Driver
  module Internal
    class InternalRelationship < InternalEntity
      attr_accessor :start_node_id, :end_node_id
      attr_reader :type

      def initialize(id, start_node_id, end_node_id, type, **properties)
        super(id, properties)
        @start_node_id = start_node_id
        @end_node_id = end_node_id
        @type = type.to_sym
      end

      def start_and_end_node_ids=(start_node_id, end_node_id)
        @start_node_id = start_node_id
        @end_node_id = end_node_id
      end

      def to_s
        "relationship<#{id}>"
      end
    end
  end
end
