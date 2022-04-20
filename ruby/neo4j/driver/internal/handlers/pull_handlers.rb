module Neo4j::Driver
  module Internal
    module Handlers
      class PullHandlers
        include Spi::ResponseHandler

        class << self
          def new_bolt_v3_pull_all_handler(query, run_handler, connection, bookmark_holder, tx)
            completion_listener = create_pull_response_completion_listener(connection, bookmark_holder, tx)
            LegacyPullAllResponseHandler.new(query, run_handler, connection, Messaging::V3::BoltProtocolV3::METADATA_EXTRACTOR, completion_listener)
          end

          def new_bolt_v4_auto_pull_handler(query, run_handler, connection, bookmark_holder, tx, fetch_size)
            completion_listener = create_pull_response_completion_listener(connection, bookmark_holder, tx)
            Pulln::AutoPullResponseHandler.new(query, run_handler, connection, Messaging::V3::BoltProtocolV3::METADATA_EXTRACTOR, completion_listener, fetch_size)
          end

          def new_bolt_v4_basic_pull_handler(query, run_handler, connection, bookmark_holder, tx)
            completion_listener = create_pull_response_completion_listener(connection, bookmark_holder, tx)
            Pulln::BasicPullResponseHandler.new(query, run_handler, connection, Messaging::V3::BoltProtocolV3::METADATA_EXTRACTOR, completion_listener)
          end

          private

          def create_pull_response_completion_listener(connection, bookmark_holder, tx)
            tx.nil? ? SessionPullResponseCompletionListener.new(connection, bookmark_holder) : TransactionPullResponseCompletionListener.new(tx)
          end
        end
      end
    end
  end
end
