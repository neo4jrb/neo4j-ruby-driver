module Bolt
  module Connector
    extend FFI::Library
    ffi_lib ENV['SEABOLT_LIB']

    BoltAccessMode = enum(
      :bolt_access_mode_write,
      :bolt_access_mode_read
    )

    attach_function :create, :BoltConnector_create, [:pointer, :pointer, :pointer], :pointer
    attach_function :destroy, :BoltConnector_destroy, [:pointer], :void
    attach_function :acquire, :BoltConnector_acquire, [:pointer, BoltAccessMode, :pointer], :pointer
    attach_function :release, :BoltConnector_release, [:pointer, :pointer], :void
  end
end