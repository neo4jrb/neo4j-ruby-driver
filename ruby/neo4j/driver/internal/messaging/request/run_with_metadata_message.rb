module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class RunWithMetadataMessage < MessageWithMetadata
          SIGNATURE = 0x10

          attr_reader = :query, :parameters

          class << self
            def auto_commit_tx_run_message(query, config, database_name, mode, bookmark, impersonated_user, tx_timeout = nil, tx_metadata = nil)
              tx_metadata = tx_metadata.present? ? tx_metadata : config.metadata
              tx_timeout = tx_timeout.present? ? tx_timeout : config.timeout
              metadata = Request::TransactionMetadataBuilder.build_metadata(tx_timeout, tx_metadata, database_name, mode, bookmark, impersonated_user)
              new(query.text, query.parameters.as_map(Values.of_value), metadata)
            end

            def unmanaged_tx_run_message(query)
              new(query.text, query.parameters.as_map(Values.of_value), java.util.Collections.empty_map)
            end
          end

          def initialize(query, parameters, metadata)
            super(metadata)
            @query = query
            @parameters = parameters
          end

          def equals(object)
            return true if self == object

            return false if object.nil? || self.class != object.class

            java.util.Objects.equals(query, object.query) && java.util.Objects.equals(parameters, object.parameters) && java.util.Objects.equals(metadata, object.metadata)
          end

          def hash_code
            java.util.Objects.hash(query, parameters, metadata)
          end

          def to_s
            "RUN \"#{query}\" #{parameters} #{metadata}"
          end
        end
      end
    end
  end
end
