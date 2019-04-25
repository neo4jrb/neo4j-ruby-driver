# frozen_string_literal: true

module Bolt
  module Buffer
    extend Bolt::Library

    attach_function :create, :BoltBuffer_create, %i[int], :pointer
    attach_function :destroy, :BoltBuffer_destroy, %i[pointer], :void
    attach_function :compact, :BoltBuffer_compact, %i[pointer], :void
    attach_function :loadable, :BoltBuffer_loadable, %i[pointer], :int
    attach_function :load_pointer, :BoltBuffer_load_pointer, %i[pointer int], :pointer
    attach_function :load, :BoltBuffer_load, %i[pointer string int], :void
    attach_function :load_u8, :BoltBuffer_load_u8, %i[pointer uint8_t], :void
    attach_function :load_u16be, :BoltBuffer_load_u16be, %i[pointer uint16_t], :void
    attach_function :load_i8, :BoltBuffer_load_i8, %i[pointer int8_t], :void
    attach_function :load_i16be, :BoltBuffer_load_i16be, %i[pointer uint16_t], :void
    attach_function :load_i32be, :BoltBuffer_load_i32be, %i[pointer int32_t], :void
    attach_function :load_i64be, :BoltBuffer_load_i64be,  %i[pointer int64_t], :void
    attach_function :load_f64be, :BoltBuffer_load_f64be, %i[pointer double], :void
    attach_function :unloadable, :BoltBuffer_unloadable, %i[pointer], :int
    attach_function :unload_pointer, :BoltBuffer_unload_pointer, %i[pointer int], :pointer
    attach_function :unload, :BoltBuffer_unload, %i[pointer pointer int], :int
    attach_function :peek_u8, :BoltBuffer_peek_u8, %i[pointer pointer], :int
    attach_function :unload_u8, :BoltBuffer_unload_u8, %i[pointer pointer], :int
    attach_function :unload_u16be, :BoltBuffer_unload_u16be, %i[pointer pointer], :int
    attach_function :unload_i8, :BoltBuffer_unload_i8, %i[pointer pointer], :int
    attach_function :unload_i16be, :BoltBuffer_unload_i16be, %i[pointer pointer], :int
    attach_function :unload_i32be, :BoltBuffer_unload_i32be, %i[pointer pointer], :int
    attach_function :unload_i64be, :BoltBuffer_unload_i64be, %i[pointer pointer], :int
    attach_function :unload_f64be, :BoltBuffer_unload_f64be, %i[pointer pointer], :int
  end
end