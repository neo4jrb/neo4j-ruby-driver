module Neo4j::Driver
  module Internal
    class ResolvedBoltServerAddress < BoltServerAddress
      MAX_HOST_ADDRESSES_IN_STRING_VALUE = 5

      def initialize(host, port, *resolved_addresses_arr)
        super(host: host, port: port)
        if resolved_addresses_arr.empty?
          raise ArgumentError,
                'The resolvedAddressesArr must not be empty, check your DomainNameResolver is compliant with the interface contract'
        end
        @resolved_addresses = resolved_addresses_arr.to_set.freeze
        @string_value = create_string_representation
      end

      def unicast_stream
        @resolved_addresses
          .map { |address| BoltServerAddress.new(host: host, connection_host: address.ip_address, port: port) }
      end

      def to_s
        @string_value
      end

      def attributes
        super + [@resolved_addresses]
      end

      def create_string_representation
        host_addresses = @resolved_addresses.take(MAX_HOST_ADDRESSES_IN_STRING_VALUE).map(&:ip_address).join(',')
        "#{host}(#{host_addresses}#{',...' if @resolved_addresses.size > MAX_HOST_ADDRESSES_IN_STRING_VALUE}):#{port}"
      end
    end
  end
end
