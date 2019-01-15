# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module AutoClosable
        def auto_closable(*methods)
          prepend with_block_definer(methods)
        end

        private

        def with_block_definer(methods)
          Module.new do
            methods.each do |method|
              define_method(method) do |*args, &block|
                closable = super(*args)
                if block
                    block.arity.zero? ? closable.instance_eval(&block) : block.call(closable)
                else
                  closable
                end
              ensure
                closable&.close if block
              end
            end
          end
        end
      end
    end
  end
end
