# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Messaging
        module V3
          class BoltProtocolV3
            VERSION = 3
            INSTANCE = new
            METADATA_EXTRACTOR = Util::MetadataExtractor.new('t_first', 't_last')

            def run_in_auto_commit_transaction(connection, statement, bookmarks_holder, config)
              self.class.run_statement(connection, statement, bookmarks_holder, nil, config)
            end

            def run_in_explicit_transaction(connection, statement, tx)
              self.class.run_statement(connection, statement, BookmarksHolder::NO_OP, tx, nil)
            end

            def begin_transaction(connection, bookmarks, config)
              begin_handler = Handlers::ResponseHandler.new(connection)
              connection.begin(bookmarks, config, begin_handler)
              connection.flush if bookmarks.present?
              begin_handler
            end

            def commit_transaction(connection)
              Handlers::ResponseHandler.new(connection).tap(&connection.method(:commit))
            end

            def rollback_transaction(connection)
              Handlers::ResponseHandler.new(connection).tap(&connection.method(:rollback))
            end

            class << self
              def run_statement(connection, statement, boomarks_holder, tx, config)
                query = statement.text
                params = statement.parameters

                run_handler = Handlers::RunResponseHandler.new(connection, METADATA_EXTRACTOR)
                pull_all_handler = new_pull_all_handler(statement, run_handler, connection, boomarks_holder, tx)

                connection.write_and_flush(query, params, boomarks_holder, config, run_handler, pull_all_handler)
                InternalResult.new(run_handler, pull_all_handler)
              end

              def new_pull_all_handler(statement, run_handler, connection, bookmarks_holder, tx)
                if tx
                  Handlers::TransactionPullAllResponseHandler.new(statement, run_handler, connection, tx,
                                                                  METADATA_EXTRACTOR)
                else
                  Handlers::SessionPullAllResponseHandler.new(statement, run_handler, connection, bookmarks_holder,
                                                              METADATA_EXTRACTOR)
                end
              end
            end
          end
        end
      end
    end
  end
end
