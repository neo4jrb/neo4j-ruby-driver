# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.7. FAILURE switches to a GQL-flavoured map: the legacy
        # `code` key is renamed to `neo4j_code` (optional, defaults to
        # "N/A"), and new keys appear (`gql_status`, `description`,
        # `diagnostic_record`, recursive `cause`). The driver's
        # exception classifier keys off `:code`, so we alias
        # `neo4j_code → code` here. The other GQL fields ride along in
        # the metadata for any caller that wants them.
        #
        # 5.7+ is also where HandshakeManifestV1 negotiation becomes
        # mandatory on the server side; that's handled in Bolt::Handshake,
        # not here.
        class V5_7 < V5_6
          def customize_hydration(unpacker)
            super
            unpacker.register_hydration_handler(Message::FAILURE) do |fields|
              meta = fields[0] || {}
              meta = meta.merge(code: meta[:neo4j_code]) if meta[:neo4j_code]
              Message::Failure.new(meta)
            end
          end
        end
      end
    end
  end
end
