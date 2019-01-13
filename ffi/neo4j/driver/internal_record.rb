# frozen_string_literal: true

class InternalRecord
  def initialize(connection)
    @connection = connection
  end

  def first
    field_values = Bolt::Connection.field_values(@connection)
    field_value = Bolt::Values.bolt_list_value(field_values, 0)
    string_buffer = FFI::Buffer.alloc_out(:char, 4096)

    string_buffer[4095] = 0 if Bolt::Values.bolt_value_to_string(field_value, string_buffer, 4096, @connection) > 4096

    string_buffer.get_string(0)
  end
end
