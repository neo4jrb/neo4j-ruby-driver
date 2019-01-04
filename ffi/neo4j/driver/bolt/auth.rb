module Bolt
  module Auth
    extend FFI::Library
    ffi_lib ENV['SEABOLT_LIB']
    attach_function :basic, :BoltAuth_basic, [:string, :string, :string], :pointer
    # attach_function :destroy, :BoltAuth_destroy, [:pointer], :void
  end
end