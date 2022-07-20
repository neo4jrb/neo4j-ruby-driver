module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class RunWithMetadataMessage < MessageWithMetadata
          SIGNATURE = 0x10
          attr_reader :query, :parameters

          class << self
            def auto_commit_tx_run_message(query, config, database_name, mode, bookmark, impersonated_user)
              metadata = Request::TransactionMetadataBuilder.build_metadata(
                tx_timeout: config[:timeout], tx_metadata: config[:metadata], database_name: database_name, mode: mode,
                bookmark: bookmark, impersonated_user: impersonated_user)
              new(query.text, query.parameters, metadata)
            end

            def unmanaged_tx_run_message(query)
              new(query.text, query.parameters, {})
            end
          end

          def initialize(query, parameters, metadata)
            super(metadata)
            @query = query
            @parameters = parameters
          end

          def signature
            SIGNATURE
          end

          def ==(other)
            super && query == other.query && parameters == other.parameters
          end

          alias eql? ==

          def hash
            [query, parameters, metadata].hash
          end

          def to_s
            "RUN \"#{query}\" #{parameters} #{metadata}"
          end
        end
      end
    end
  end
end
