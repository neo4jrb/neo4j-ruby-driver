# frozen_string_literal: true

module Bolt
  module AutoReleasable
    def auto_release(method, options = {})
      singleton_class.prepend with_auto_releaser(method, options)
    end

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
