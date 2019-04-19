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

    attach_function :destroy, :BoltValue_destroy, [:pointer], :void
    attach_function :format_as_string, :BoltValue_format_as_String, %i[pointer string int32_t], :void
    attach_function :size, :BoltValue_size, %i[pointer], :int32_t
    attach_function :to_string, :BoltValue_to_string, %i[pointer pointer int32_t pointer], :int32_t
    attach_function :type, :BoltValue_type, [:pointer], :bolt_type
  end
end
