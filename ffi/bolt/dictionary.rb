# frozen_string_literal: true

module Bolt
  module Dictionary
    extend Bolt::Library

    attach_function :key, :BoltDictionary_key, %i[pointer int32], :pointer
    attach_function :get_key, :BoltDictionary_get_key, %i[pointer int32], :strptr
    attach_function :get_key_size, :BoltDictionary_get_key_size, %i[pointer int32], :int32
    attach_function :get_key_index, :BoltDictionary_get_key_index, %i[pointer string int32 int32], :int32
    attach_function :set_key, :BoltDictionary_set_key, %i[pointer int32 string int32], :int32
    attach_function :value, :BoltDictionary_value, %i[pointer int32], :pointer
    attach_function :value_by_key, :BoltDictionary_value_by_key, %i[pointer string int32], :pointer
  end
end
