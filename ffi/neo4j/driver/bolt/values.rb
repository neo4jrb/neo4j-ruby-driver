# frozen_string_literal: true

module Bolt
  module Values
    extend FFI::Library
    ffi_lib ENV['SEABOLT_LIB']

    attach_function :bolt_value_destroy, :BoltValue_destroy, [:pointer], :void
    attach_function :bolt_value_format_as_string, :BoltValue_format_as_String, %i[pointer string int32_t], :void
    attach_function :bolt_value_to_string, :BoltValue_to_string, %i[pointer pointer int32_t pointer], :int32_t
    attach_function :bolt_list_value, :BoltList_value, %i[pointer int32_t], :pointer
  end
end
