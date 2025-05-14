# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalSession
        extend AutoClosable
        extend Gem::Deprecate
        include ConfigConverter
        include ExceptionCheckable
        include RunOverride

        auto_closable :begin_transaction

        # work around jruby issue https://github.com/jruby/jruby/issues/5603
        Struct.new('Wrapper', :object)

        # implementation of read_transaction, write_transaction, execute_read, execute_write
        %i[read write].each do |mode|
          ["#{mode}_transaction", "execute_#{mode}"].each do |method_name|
            define_method(method_name) do |**config, &block|
              check do
                super(
                  ->(tx) { Struct::Wrapper.new(reverse_check { block.call(tx) }) },
                  to_java_config(Neo4j::Driver::TransactionConfig, **config)
                ).object
              end
            end
          end
        end

        # TODO: Specify the date when the method will be removed
        deprecate :read_transaction, "InternalSession#execute_read", 2026, 01
        deprecate :write_transaction, "InternalSession#execute_write", 2026, 01

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
      end
    end
  end
end
