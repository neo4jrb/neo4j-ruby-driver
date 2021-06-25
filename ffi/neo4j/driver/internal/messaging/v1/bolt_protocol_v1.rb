# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Messaging
        module V1
          class BoltProtocolV1
            VERSION = 1
            INSTANCE = new

            METADATA_EXTRACTOR = Util::MetadataExtractor.new('result_available_after', 'result_consumed_after')

            def run_in_auto_commit_transaction(connection, statement, bookmarks_holder, config)
              # bookmarks are ignored for auto-commit transactions in this version of the protocol

              self.class.tx_config_not_supported if config&.present?

              self.class.run_statement(connection, statement, nil)
            end

            def run_in_explicit_transaction(connection, statement, tx)
              self.class.run_statement(connection, statement, tx)
            end

            class << self
              def run_statement(connection, statement, tx)
                query = statement.text
                params = statement.parameters

                run_handler = Handlers::RunResponseHandler.new(METADATA_EXTRACTOR)
                pull_all_handler = new_pull_all_handler(statement, run_handler, connection, tx)

                connection.write_and_flush(query, params, run_handler, pull_all_handler)
                InternalResult.new(run_handler, pull_all_handler)
              end

              def new_pull_all_handler(statement, run_handler, connection, tx)
                if tx
                  Handlers::TransactionPullAllResponseHandler.new(statement, run_handler, connection, tx,
                                                                  METADATA_EXTRACTOR)
                else
                  Handlers::SessionPullAllResponseHandler.new(statement, run_handler, connection,
                                                              BookmarksHolder::NO_OP, METADATA_EXTRACTOR)
                end
              end

              def tx_config_not_supported
                raise ClientException,
                      'Driver is connected to the database that does not support transaction configuration. ' \
                      'Please upgrade to neo4j 3.5.0 or later in order to use this functionality'
              end
            end
          end
        end
      end
    end
  end
end
