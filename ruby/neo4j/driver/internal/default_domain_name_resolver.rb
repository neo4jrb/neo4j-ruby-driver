module Neo4j::Driver
  module Internal
    class DefaultDomainNameResolver
      INSTANCE = new

      def resolve(name)
        java.net.InetAddress.get_all_by_name(name)
      end
    end
  end
end
