# frozen_string_literal: true

module Bolt
  module Lifecycle
    extend FFI::Library
    ffi_lib ENV['SEABOLT_LIB']
    attach_function :bolt_startup, :Bolt_startup, [], :void
    attach_function :bolt_shutdown, :Bolt_shutdown, [], :void
  end
end
