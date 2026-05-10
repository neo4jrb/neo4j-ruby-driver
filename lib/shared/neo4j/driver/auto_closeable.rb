# frozen_string_literal: true

module Neo4j
  module Driver
    module AutoCloseable
      def auto_closeable(*methods)
        prepend with_block_definer(methods)
      end

      private

      def with_block_definer(methods)
        Module.new do
          methods.each do |method|
            define_method(method) do |*args, **kwargs, &block|
              closeable = super(*args, **kwargs)
              if block
                begin
                  block.arity.zero? ? closeable.instance_eval(&block) : block.call(closeable)
                ensure
                  closeable&.close
                end
              else
                closeable
              end
            end
          end
        end
      end
    end
  end
end
