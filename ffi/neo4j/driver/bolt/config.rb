module Bolt
  module Config
    extend FFI::Library
    ffi_lib ENV['SEABOLT_LIB']
    attach_function :create, :BoltConfig_create, [], :pointer
    attach_function :destroy, :BoltConfig_destroy, [:pointer], :void
    attach_function :set_user_agent, :BoltConfig_set_user_agent, [:pointer, :string], :int32_t
  end
end