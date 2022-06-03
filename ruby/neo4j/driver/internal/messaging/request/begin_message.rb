module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class BeginMessage < MessageWithMetadata
          SIGNATURE = 0x11

          def initialize(bookmark, config, database_name, mode, impersonated_user)
            super(Request::TransactionMetadataBuilder.build_metadata(
              tx_timeout: config[:timeout]&.then(&DurationNormalizer.method(:milliseconds)),
              tx_metadata: config[:metadata], database_name: database_name, mode: mode, bookmark: bookmark,
              impersonated_user: impersonated_user))
          end

          def signature
            SIGNATURE
          end

          def to_s
            "BEGIN #{metadata}"
          end
        end
      end
    end
  end
end
