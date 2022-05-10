module Neo4j::Driver
  module Internal
    module Messaging
      module V3
        class BoltProtocolV3
          VERSION = BoltProtocolVersion.new(3, 0)
          INSTANCE = new
          METADATA_EXTRACTOR = Util::MetadataExtractor.new('t_first', 't_last')

          def create_message_format
            MessageFormatV3.new
          end

          def initialize_channel(channel, user_agent, auth_token, routing_context)
            message = Request::HelloMessage.new(user_agent, auth_token,
                                                (routing_context.to_map if routing_context.server_routing_enabled?))
            handler = Handlers::HelloResponseHandler.new(channel, VERSION)

            channel.message_dispatcher.enqueue(handler)
            channel.write_and_flush(message)
          end

          def prepare_to_close_channel(channel)
            message_dispatcher = Connection::ChannelAttributes.message_dispatcher(channel)

            message = Request::GoodbyeMessage::GOODBYE
            message_dispatcher.enqueue(Handlers::NoOpResponseHandler::INSTANCE)
            channel.write_and_flush(message, channel.void_promise)

            message_dispatcher.prepare_to_close_channel
          end

          def begin_transaction(connection, bookmark, config)
            verify_database_name_before_transaction(connection.database_name)
            begin_message = Request::BeginMessage.new(bookmark, config, connection.database_name, connection.mode, connection.impersonated_user)
            connection.write_and_flush(begin_message, Handlers::BeginTxResponseHandler.new)
          end

          def commit_transaction(connection)
            connection.write_and_flush(Request::CommitMessage::COMMIT, Handlers::CommitTxResponseHandler.new(commit_future))
            commit_future
          end

          def rollback_transaction(connection)
            rollback_future = java.util.concurrent.CompletableFuture.new
            connection.write_and_flush(Request::RollbackMessage::ROLLBACK, Handlers::RollbackTxResponseHandler.new(rollback_future))

            rollback_future
          end

          def run_in_auto_commit_transaction(connection, query, bookmark_holder, config, fetch_size)
            verify_database_name_before_transaction(connection.database_name)

            run_message = Request::RunWithMetadataMessage.auto_commit_tx_run_message(query, config, connection.database_name, connection.mode, bookmark_holder.bookmark, connection.impersonated_user)

            build_result_cursor_factory(connection, query, bookmark_holder, nil, run_message, fetch_size)
          end

          def run_in_unmanaged_transaction(connection, query, tx, fetch_size)
            run_message = Request::RunWithMetadataMessage.unmanaged_tx_run_message(query)
            build_result_cursor_factory(connection, query, BookmarkHolder::NO_OP, tx, run_message, fetch_size)
          end

          def build_result_cursor_factory(connection, query, bookmark_holder, tx, run_message, ignored)
            run_future = java.util.concurrent.CompletableFuture.new
            run_handler = Handlers::RunResponseHandler.new(run_future, METADATA_EXTRACTOR, connection, tx)
            pull_handler = Handlers::PullHandlers.new_bolt_v3_pull_all_handler(query, run_handler, connection, bookmark_holder, tx)

            Cursor::AsyncResultCursorOnlyFactory.new(connection, run_message, run_handler, run_future, pull_handler)
          end

          def verify_database_name_before_transaction(database_name)
            Request::MultiDatabaseUtil.assert_empty_database_name(database_name, VERSION)
          end

          def version
            self.class::VERSION
          end
        end
      end
    end
  end
end
