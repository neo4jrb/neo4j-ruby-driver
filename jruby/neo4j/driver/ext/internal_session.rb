# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalSession
        extend AutoClosable
        include ConfigConverter
        include ExceptionCheckable
        include RunOverride

        auto_closable :begin_transaction

        # work around jruby issue https://github.com/jruby/jruby/issues/5603
        Struct.new('Wrapper', :object)

        %i[read write].each do |prefix|
          define_method("#{prefix}_transaction") do |**config, &block|
            check do
              super(->(tx) { Struct::Wrapper.new(reverse_check { block.call(tx) }) }, to_java_config(Neo4j::Driver::TransactionConfig, config)).object
            end
          end
        end

        # end work around

        def run(statement, parameters = {}, config = {})
          check do
            java_method(:run, [org.neo4j.driver.Query, org.neo4j.driver.TransactionConfig])
              .call(to_statement(statement, parameters), to_java_config(Neo4j::Driver::TransactionConfig, config))
          end
        end

        def begin_transaction(**config)
          check { super(to_java_config(Neo4j::Driver::TransactionConfig, config)) }
        end
      end
    end
  end
end
