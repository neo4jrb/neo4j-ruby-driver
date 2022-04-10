# frozen_string_literal: true

module Neo4j::Driver::Internal::Summary
  class InternalServerInfo < Struct.new(:agent, :address, :version, :protocol_version)
  end
end
