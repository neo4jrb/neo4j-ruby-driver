# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # Server metadata reported in the SUCCESS response.
      class ServerInfo
        attr_reader :address, :agent, :protocol_version

        def initialize(server_data = nil, address: nil, agent: nil, protocol_version: nil)
          case server_data
          when String
            @agent = server_data
            @address = address
            @protocol_version = protocol_version
          when Hash
            @address = server_data[:address] || address
            @agent = server_data[:agent] || agent
            @protocol_version = server_data[:protocol_version] || protocol_version
          else
            @address = address
            @agent = agent
            @protocol_version = protocol_version
          end
        end

        def to_s
          @agent || 'Unknown'
        end
      end
    end
  end
end
