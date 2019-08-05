# frozen_string_literal: true

module Bolt
  module AutoReleasable
    extend FFI::Library
    ffi_lib ENV['SEABOLT_LIB']

    puts "env: #{ENV['SEABOLT_LIB']}"

    def attach_function(name, func, args, returns = nil, options = nil)
      return super unless returns == :auto_pointer

      super(name, func, args, :pointer, options)
      singleton_class.prepend with_auto_releaser(name, options&.dig(:releaser))
    end

    private

    def with_auto_releaser(method, releaser)
      Module.new do
        define_method(method) do |*args|
          FFI::AutoPointer.new(super(*args), releaser || self.method(:destroy))
        end
      end
    end
  end
end
