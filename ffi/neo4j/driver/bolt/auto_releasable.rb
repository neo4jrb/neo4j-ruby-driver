# frozen_string_literal: true

module Bolt
  module AutoReleasable
    def auto_release(method, options = {})
      singleton_class.prepend with_auto_releaser(method, options)
    end

    ## Adds additional options to allow ointer results being wrapped into FFI::AutoPointer
    #
    # @option options [Boolean] :auto_release set to true if the result of the C function should be wrapped into
    # autopointer (default: false)
    # @option options [Symbol] :name optional alternative name for the method supporting autorelease, the method with
    # the original name remains untouched in this name is provided
    # @option options [Symbol] :module module that provides the release method (default: self)
    # @option options [Symbol] :method method implementing the release (default: :destroy)

    def attach_function(name, func, args, returns = nil, options = nil)
      super
      auto_release(name, options.slice(:name, :module, :method)) if options&.dig(:auto_release)
    end

    private

    def with_auto_releaser(method, options)
      name = options[:name]
      Module.new do
        define_method(name || method) do |*args|
          FFI::AutoPointer.new(name ? send(method, *args) : super(*args),
                               (options[:module] || self).method(options[:method] || :destroy))
        end
      end
    end
  end
end
