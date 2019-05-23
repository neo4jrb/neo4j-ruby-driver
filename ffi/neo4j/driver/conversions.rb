# frozen_string_literal: true

module Neo4j
  module Driver
    module Conversions
      private

      def to_string(field_value, connection = nil)
        size = Bolt::Value.size(field_value)
        string_buffer = FFI::Buffer.alloc_out(:char, size)
        Bolt::Value.to_string(field_value, string_buffer, size, connection)
        string_buffer.get_string(0)
      end
    end
  end
end
