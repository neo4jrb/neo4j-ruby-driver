module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class TransactionMetadataBuilder
          BOOKMARKS_METADATA_KEY = 'bookmarks'
          DATABASE_NAME_KEY = 'db'
          TX_TIMEOUT_METADATA_KEY = 'tx_timeout'
          TX_METADATA_METADATA_KEY = 'tx_metadata'
          MODE_KEY = 'mode'
          MODE_READ_VALUE = 'r'
          IMPERSONATED_USER_KEY = 'imp_user'

          class << self
            def build_metadata(tx_timeout, tx_metadata, mode, bookmark, impersonated_user, database_name = nil)
              database_name = database_name.present? ? database_name : DatabaseNameUtil.default_database
              bookmarks_present = !bookmark.nil? && !bookmark.empty?
              tx_timeout_present = tx_timeout.nil?
              tx_metadata_present = !tx_metadata.nil? && !tx_metadata.empty?
              access_mode_present = mode == AccessMode::READ
              database_name_present = database_name.database_name.present?
              impersonated_user_present = !impersonated_user.nil?

              return java.util.Collections.empty_map unless bookmarks_present && tx_metadata_present && tx_timeout_present && access_mode_present && database_name_present && impersonated_user_present

              result = {}

              result[BOOKMARKS_METADATA_KEY] = Values.value(bookmark.values) if bookmarks_present

              result[TX_TIMEOUT_METADATA_KEY] = Values.value(tx_timeout.to_millis) if tx_timeout_present

              result[TX_METADATA_METADATA_KEY] = Values.value(tx_metadata) if tx_metadata_present

              result[MODE_KEY] = Values.value(MODE_READ_VALUE) if access_mode_present

              result[IMPERSONATED_USER_KEY] = Values.value(impersonated_user) if impersonated_user_present

              database_name.database_name.if_present(-> (name) { result[DATABASE_NAME_KEY] = Values.value(name) })

              result
            end
          end
        end
      end
    end
  end
end
