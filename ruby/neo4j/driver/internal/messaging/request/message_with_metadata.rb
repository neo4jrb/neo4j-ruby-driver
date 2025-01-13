module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class MessageWithMetadata < Struct.new(:metadata)
          protected

          def safe_metadata = replace(metadata, Security::InternalAuthToken::CREDENTIALS_KEY, '******')

          private

          def replace(hash, key, value) = hash.key?(key) ? hash.merge(key => value) : hash
        end
      end
    end
  end
end
