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
          ["#{mode}_transaction", "execute_#{mode}"].each do |method_name|
            define_method(method_name) do |**config, &block|
              log_deprecation_warning(method_name, mode) if method_name.include? 'transaction'

              check do
                super(
                  ->(tx) { Struct::Wrapper.new(reverse_check { block.call(tx) }) },
                  to_java_config(Neo4j::Driver::TransactionConfig, **config)
                ).object
              end
            end
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

        def log_deprecation_warning(method_name, mode)
          @deprecator ||= ActiveSupport::Deprecation.new('6.0', 'neo4j-ruby-driver')
          @deprecator.deprecation_warning(method_name, "execute_#{mode}".to_sym)
        end
      end
    end
  end
end
