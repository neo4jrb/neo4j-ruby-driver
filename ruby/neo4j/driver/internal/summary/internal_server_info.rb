module Neo4j::Driver::Internal::Summary
  class InternalServerInfo < Struct.new(:agent, :address, :version, :protocol_version)
    def eql?(obj)
      return true if self == obj

      return false unless obj.instance_of?(self.class)

      address == obj.address && version == obj.version
    end

    def to_s
      "InternalServerInfo{address='#{address}', version='#{version}'}"
    end
  end
end
