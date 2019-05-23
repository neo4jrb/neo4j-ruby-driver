# frozen_string_literal: true

module Bolt
  module Value
    extend Bolt::Library

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

    attach_function :create, :BoltValue_create, [], :auto_pointer
    attach_function :destroy, :BoltValue_destroy, %i[pointer], :void
    attach_function :duplicate, :BoltValue_duplicate, %i[pointer], :pointer
    attach_function :copy, :BoltValue_copy, %i[pointer pointer], :void
    attach_function :size, :BoltValue_size, %i[pointer], :int32_t
    attach_function :type, :BoltValue_type, %i[pointer], :bolt_type
    attach_function :to_string, :BoltValue_to_string, %i[pointer pointer int32_t pointer], :int32_t
    attach_function :format_as_null, :BoltValue_format_as_Null, %i[pointer], :void
    attach_function :format_as_boolean, :BoltValue_format_as_Boolean, %i[pointer char], :void
    attach_function :format_as_integer, :BoltValue_format_as_Integer, %i[pointer int64_t], :void
    attach_function :format_as_float, :BoltValue_format_as_Float, %i[pointer double], :void
    attach_function :format_as_string, :BoltValue_format_as_String, %i[pointer string int32_t], :void
    attach_function :format_as_dictionary, :BoltValue_format_as_Dictionary, %i[pointer int32_t], :void
    attach_function :format_as_list, :BoltValue_format_as_List, %i[pointer int32_t], :void
    attach_function :format_as_bytes, :BoltValue_format_as_Bytes, %i[pointer string int32_t], :void
    attach_function :format_as_structure, :BoltValue_format_as_Structure, %i[pointer int16_t int32_t], :void
  end
end
