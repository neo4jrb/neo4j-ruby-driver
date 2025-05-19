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

        # implementation of read_transaction, write_transaction, execute_read, execute_write
        %i[read write].each do |mode|
          define_method("execute_#{mode}") do |**config, &block|
            execute_transaction(__method__, **config, &block)
          end

          define_method("#{mode}_transaction") do |**config, &block|
            Neo4j::Driver::Internal::Deprecator.log_warning("#{mode}_transaction", "execute_#{mode}".to_sym, '6.0')
            execute_transaction(__method__, **config, &block)
          end
        end

        # end work around

        def run(statement, parameters = {}, config = {})
          check do
            java_method(:run, [org.neo4j.driver.Query, org.neo4j.driver.TransactionConfig])
              .call(to_statement(statement, parameters), to_java_config(Neo4j::Driver::TransactionConfig, **config))
          end
        end

        def begin_transaction(**config)
          check { super(to_java_config(Neo4j::Driver::TransactionConfig, **config)) }
        end

        private

        def execute_transaction(method, **config, &block)
          check do
            method(method)
              .super_method
              .call( ->(tx) { Struct::Wrapper.new(reverse_check { block.call(tx) }) }, to_java_config(Neo4j::Driver::TransactionConfig, **config))
              .object
          end
        end
      end
    end
  end
end
