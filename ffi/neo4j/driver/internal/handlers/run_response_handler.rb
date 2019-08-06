# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Handlers
        class RunResponseHandler < ResponseHandler
          attr_reader :results_available_after

          def initialize(connection, metadata_extractor)
            super(connection)
            @statement_keys = []
            @metadata_extractor = metadata_extractor
          end

          def statement_keys
            finalize
            @statement_keys
          end

          def finalize
            return if @finished
            super
            @statement_keys = Value.to_ruby(Bolt::Connection.field_names(bolt_connection))
            metadata = Value.to_ruby(Bolt::Connection.metadata(bolt_connection))
            @results_available_after = metadata[:result_available_after] || metadata[:t_first]
          end
        end
      end
    end
  end
end