# frozen_string_literal: true

module Neo4j
  module Driver
    module Conversions
      private

      def to_string(field_value, connection = nil)
        size = Bolt::Values.bolt_value_size(field_value)
        string_buffer = FFI::Buffer.alloc_out(:char, size)
        Bolt::Values.bolt_value_to_string(field_value, string_buffer, size, connection)
        string_buffer.get_string(0)
      end
    end
  end
end
