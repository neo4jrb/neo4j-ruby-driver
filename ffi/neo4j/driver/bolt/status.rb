module Bolt
  module Status
    extend FFI::Library
    ffi_lib ENV['SEABOLT_LIB']

    typedef :int32_t, :bolt_connection_state

    attach_function :create, :BoltStatus_create, [], :pointer
    attach_function :destroy, :BoltStatus_destroy, [:pointer], :void
    attach_function :state, :BoltStatus_get_state, [:pointer], :bolt_connection_state
    attach_function :error, :BoltStatus_get_error, [:pointer], :int32_t
    attach_function :error_context, :BoltStatus_get_error_context, [:pointer], :string
  end
end