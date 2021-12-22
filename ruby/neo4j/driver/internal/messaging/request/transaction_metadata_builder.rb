module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class TransactionMetadataBuilder
          class << self
            def build_metadata(tx_timeout:, tx_metadata:, mode:, bookmark:, impersonated_user:,
                               database_name: DatabaseNameUtil.default_database)
              { bookmarks: bookmark,
                tx_timeout: tx_timeout,
                tx_metadata: tx_metadata,
                mode: (MODE_READ_VALUE if mode == AccessMode::READ),
                db: database_name.database_name,
                imp_user: impersonated_user
              }.filter { |_, value| value.present? }
            end
          end
        end
      end
    end
  end
end
