# frozen_string_literal: true

module Neo4j::Driver::Internal::Summary
  class InternalNotification
    attr_reader :code, :title, :description, :severity, :position

    VALUE_TO_NOTIFICATION = lambda do |value|
      code = value['code'].to_s
      title = value['title'].to_s
      description = value['description'].to_s
      severity = value.key?('severity') ? value['severity'].to_s : 'N/A'
      position = nil

      pos_value = value['position']
      unless pos_value.nil?
        position = InternalInputPosition.new(pos_value['offset'].to_i, pos_value['line'].to_i, pos_value['column'].to_i)
      end

      InternalNotification.new(code, title, description, severity, position)
    end

    def initialize(code, title, description, severity, position)
      @code = code
      @title = title
      @description = description
      @severity = severity
      @position = position
    end

    def to_s
      info = "code=#{code}, title=#{title}, description=#{description}, severity=#{severity}"
      info << ", position={#{position}}" if position

      info
    end
  end
end
