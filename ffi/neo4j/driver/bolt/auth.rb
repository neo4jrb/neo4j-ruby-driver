# frozen_string_literal: true

module Bolt
  module Auth
    extend FFI::Library
    ffi_lib ENV['SEABOLT_LIB']
    attach_function :basic, :BoltAuth_basic, %i[string string string], :pointer
    # attach_function :destroy, :BoltAuth_destroy, [:pointer], :void
  end
end
