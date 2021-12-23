# frozen_string_literal: true

module Neo4j::Driver::Internal::Summary
  class InternalServerInfo < Struct.new(:agent, :address, :version, :protocol_version)
    def eql?(other)
      return true if self == other

      return false unless other.instance_of?(self.class)

      address == other.address && version == other.version
    end

    def to_s
      "InternalServerInfo{address='#{address}', version='#{version}'}"
    end
  end
end
