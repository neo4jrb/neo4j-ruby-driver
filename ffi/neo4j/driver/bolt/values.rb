# frozen_string_literal: true

module Bolt
  module Values
    extend FFI::Library
    ffi_lib ENV['SEABOLT_LIB']

    enum :bolt_type,
         %i[bolt_null
            bolt_boolean
            bolt_integer
            bolt_float
            bolt_string
            bolt_dictionary
            bolt_list
            bolt_bytes
            bolt_structure]

    attach_function :bolt_list_value, :BoltList_value, %i[pointer int32_t], :pointer
    attach_function :bolt_value_destroy, :BoltValue_destroy, [:pointer], :void
    attach_function :bolt_value_format_as_string, :BoltValue_format_as_String, %i[pointer string int32_t], :void
    attach_function :bolt_value_size, :BoltValue_size, %i[pointer], :int32_t
    attach_function :bolt_value_to_string, :BoltValue_to_string, %i[pointer pointer int32_t pointer], :int32_t
    attach_function :bolt_value_type, :BoltValue_type, [:pointer], :bolt_type
    attach_function :bolt_string_get, :BoltString_get, [:pointer], :pointer
    attach_function :bolt_integer_get, :BoltInteger_get, [:pointer], :int64_t
  end
end
