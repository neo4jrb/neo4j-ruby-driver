# frozen_string_literal: true

module Bolt
  module Dictionary
    extend Bolt::Library

    attach_function :key, :BoltDictionary_key, %i[pointer int32_t], :pointer
    attach_function :get_key, :BoltDictionary_get_key, %i[pointer int32_t], :strptr
    attach_function :get_key_size, :BoltDictionary_get_key_size, %i[pointer int32_t], :int32_t
    attach_function :get_key_index, :BoltDictionary_get_key_index, %i[pointer string int32_t int32_t], :int32_t
    attach_function :set_key, :BoltDictionary_set_key, %i[pointer int32_t string int32_t], :int32_t
    attach_function :value, :BoltDictionary_value, %i[pointer int32_t], :int32_t
    attach_function :value_by_key, :BoltDictionary_value_by_key, %i[pointer string int32_t], :int32_t
  end
end
