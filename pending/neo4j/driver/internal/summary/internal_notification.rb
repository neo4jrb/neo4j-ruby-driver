# frozen_string_literal: true

module Neo4j::Driver::Internal::Summary
  class InternalNotification < Struct.new(:code, :title, :description, :severity, :position)

    VALUE_TO_NOTIFICATION = lambda do |value|
      severity = value[:severity] || 'N/A'

      position = value[:position]&.then do |pos_value|
        InternalInputPosition.new(*pos_value.values_at(:offset, :line, :column).map(&:to_i))
      end

      InternalNotification.new(*value.values_at(:code, :title, :description), severity, position)
    end
  end
end
