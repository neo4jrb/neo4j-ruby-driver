module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class TransactionMetadataBuilder
          MODE_READ_VALUE = 'r'

          class << self
            def build_metadata(timeout:, tx_metadata:, mode:, bookmarks:, impersonated_user:,
                               database_name: DatabaseNameUtil.default_database)
              { bookmarks: bookmarks.presence,
                tx_timeout: timeout&.then(&DurationNormalizer.method(:milliseconds)),
                tx_metadata: tx_metadata.presence,
                mode: (MODE_READ_VALUE if mode == AccessMode::READ),
                db: database_name&.database_name,
                imp_user: impersonated_user
              }.compact
            end
          end
        end
      end
    end
  end
end
