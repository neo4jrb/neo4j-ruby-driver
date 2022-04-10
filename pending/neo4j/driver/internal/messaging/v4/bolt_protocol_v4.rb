module Neo4j::Driver
  module Internal
    module Messaging
      module V4
        class BoltProtocolV4 < V3::BoltProtocolV3
          VERSION = BoltProtocolVersion.new(4,0)
          INSTANCE = new

          def create_message_format
            MessageFormatV4.new
          end

          def build_result_cursor_factory(connection, query, bookmark_holder, tx, run_message, fetch_size)
            run_future = java.util.concurrent.CompletableFuture.new
            run_handler = Handlers::RunResponseHandler.new(run_future, V3::BoltProtocolV3::METADATA_EXTRACTOR, connection, tx)

            pull_all_handler = Handlers::PullHandlers.new_bolt_v4_auto_pull_handler(query, run_handler, connection, bookmark_holder, tx, fetch_size)
            pull_handler = Handlers::PullHandlers.new_bolt_v4_basic_pull_handler(query, run_handler, connection, bookmark_holder, tx)

            Cursor::ResultCursorFactoryImpl.new(connection, run_message, run_handler, run_future, pull_handler, pull_all_handler)
          end
        end
      end
    end
  end
end
