module Neo4j::Driver
  module Internal
    # Holds a host and port pair that denotes a Bolt server address.
    class BoltServerAddress1
      include org.neo4j.driver.net.ServerAddress
      attr_reader :host, :connection_host, :port
      delegate :hash, to: :attributes

      DEFAULT_PORT = 7687

      class << self
        def host_from(uri)
          host = uri.get_host

          raise invalid_address_format(uri) if host.nil?

          host
        end

        def port_from(uri)
          port = uri.get_port
          port.nil? ? DEFAULT_PORT : port
        end

        def uri_from(address)
          scheme_split = address.split('://')

          if scheme_split.length == 1
            # URI can't parse addresses without scheme, prepend fake "bolt://" to reuse the parsing facility
            scheme = 'bolt://'
            host_port = host_port_from(scheme_split.first)
          elsif scheme_split.length == 2
            scheme = "#{scheme_split.first}://"
            host_port = host_port_from(scheme_split.second)
          else
            raise invalid_address_format(address)
          end

          URI(scheme + host_port)
        end

        def host_port_from(address)
          # expected to be an IPv6 address like [::1] or [::1]:7687
          return address if address.start_with?('[')

          contains_single_colon = address.index(':') == address.rindex(':')

          # expected to be an IPv4 address with or without port like 127.0.0.1 or 127.0.0.1:7687
          return address if contains_single_colon

          # address contains multiple colons and does not start with '['
          # expected to be an IPv6 address without brackets
          "[#{address}]"
        end

        def invalid_address_format(address)
          ArgumentError.new("Invalid address format #{address}")
        end

        def require_valid_port(port)
          return port if port >= 0 && port <= 65_535

          raise ArgumentError, "Illegal port: #{port}"
        end
      end

      def initialize(host, port, connection_host: host)
        @host = Validator.require_non_nil!(host)
        @connection_host = Validator.require_non_nil!(connection_host)
        @port = self.class.require_valid_port(port)
      end

      LOCAL_DEFAULT = new('localhost', DEFAULT_PORT)

      def self.from(address)
        address.instance_of?(BoltServerAddress) ? address : new(address.host, address.port)
      end

      def eql?(other)
        attributes.eql?(other&.attributes)
      end

      def to_s
        "#{host}#{"(#{connection_host})" unless host == connection_host}:#{port}"
      end

      # Create a stream of unicast addresses.
      # <p>
      # While this implementation just returns a stream of itself, the subclasses may provide multiple addresses.

      # @return stream of unicast addresses.
      def unicast_stream
        java.util.stream.Stream.of(self)
      end

      private

      def attributes
        [@host, @connection_host, @port]
      end
    end
  end
end
