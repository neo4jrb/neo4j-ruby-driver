# frozen_string_literal: true

module Neo4j::Driver
  module Internal
    class InternalRelationship < InternalEntity
      attr_accessor :start_node_id, :end_node_id, :start_node_element_id, :end_node_element_id
      attr_reader :type

      def initialize(id, element_id, start_node_id, start_node_element_id, end_node_id, end_node_element_id, type, **properties)
        super(id, element_id, **properties)
        set_start_and_end_node_ids(start_node_id, start_node_element_id, end_node_id, end_node_element_id)
        @type = type.to_sym
      end

      def set_start_and_end_node_ids(start_node_id, start_node_element_id, end_node_id, end_node_element_id)
        @start_node_id = start_node_id
        @start_node_element_id = start_node_element_id || start_node_id.to_s
        @end_node_id = end_node_id
        @end_node_element_id = end_node_element_id || end_node_id.to_s
      end

      def to_s
        "relationship<#{id}>"
      end
    end
  end
end
