# frozen_string_literal: true

module Neo4j
  module Driver
    module Synchronizable
      def sync(*methods)
        prepend with_sync_wrapper(methods)
      end

      private

      def with_sync_wrapper(methods)
        Module.new do
          methods.each do |method|
            define_method(method) do |*args, **kwargs, &block|
              Sync { super(*args, **kwargs, &block) }
            end
          end
        end
      end
    end
  end
end
