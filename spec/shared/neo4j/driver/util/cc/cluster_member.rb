# frozen_string_literal: true

module Neo4j
  module Driver
    module Util
      module CC
        class ClusterMember
          SIMPLE_SCHEME = 'bolt://'
          #ROUTING_SCHEME = 'bolt+routing://'
          ROUTING_SCHEME = 'neo4j://'

          attr_accessor :bolt_uri, :path, :bolt_address

          def initialize(bolt_uri, path)
            self.bolt_uri = bolt_uri
            self.bolt_address = Neo4j::Driver::Net::ServerAddress.of(*URI(bolt_uri).then { |uri| [uri.host, uri.port] })
            self.path = path
          end

          def routing_uri
            bolt_uri.gsub(SIMPLE_SCHEME, ROUTING_SCHEME)
          end
        end
      end
    end
  end
end
