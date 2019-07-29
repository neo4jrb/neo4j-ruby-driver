# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Handlers
        class RunResponseHandler < ResponseHandler
          def initialize(connection, metadata_extractor)
            super(connection)
            @statement_keys = []
            @metadate_extractor = metadata_extractor
          end

          def statement_keys
            finalize
            @statement_keys
          end

          def finalize
            return if @finished
            super
            @statement_keys = Value.to_ruby(Bolt::Connection.field_names(bolt_connection))
          end
        end
      end
    end
  end
end
