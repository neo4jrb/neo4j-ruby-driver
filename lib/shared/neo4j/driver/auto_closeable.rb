# frozen_string_literal: true

module Neo4j
  module Driver
    # Class-level helper: wraps the named factory methods so that, when given
    # a block, the returned resource is yielded and guaranteed closed
    # afterwards (Java try-with-resources semantics).
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
