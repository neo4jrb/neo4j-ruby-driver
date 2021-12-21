module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class BeginMessage < MessageWithMetadata
          SIGNATURE = 0x11

          def initialize(bookmark, config, database_name, mode, impersonated_user, tx_timeout = nil, tx_metadata = nil)
            tx_timeout = tx_timeout.present? ? tx_timeout : config.timeout
            tx_metadata = tx_metadata.present? ? tx_metadata : config.metadata
            super(Request.TransactionMetadataBuilder.build_metadata(tx_timeout, tx_metadata, database_name, mode, bookmark, impersonated_user))
          end

          def equals(object)
            return true if self == object

            return false if object.nil? || self.class != object.class

            java.util.Objects.equals(metadata, object.metadata)
          end

          def hash_code
            java.util.Objects.hash(metadata)
          end

          def to_s
            "BEGIN #{metadata}"
          end
        end
      end
    end
  end
end
