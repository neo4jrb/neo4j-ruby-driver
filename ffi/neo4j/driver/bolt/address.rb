# frozen_string_literal: true

module Bolt
  module Address
    extend FFI::Library
    ffi_lib ENV['SEABOLT_LIB']
    attach_function :create, :BoltAddress_create, %i[string string], :pointer
    attach_function :destroy, :BoltAddress_destroy, [:pointer], :void
  end
end
