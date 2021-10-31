# frozen_string_literal: true

module Neo4j::Driver
  class GraphDatabase
    class << self
      extend AutoClosable
      include Ext::ConfigConverter
      include Ext::ExceptionCheckable

      auto_closable :driver, :routing_driver

      GOGOBOLT = ["6060B017"].pack('H*')

      def handshake(*versions)
        remote_port = 7687
        remote_addr = 'localhost'
        selector = NIO::Selector.new
        socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
        begin
          socket.connect_nonblock Socket.sockaddr_in(remote_port, remote_addr)
        rescue Errno::EINPROGRESS
          # Ruby's a-tryin' to connect us, we swear!
          selector.register(socket, :w)
        end
        selector.select do |monitor|
          case monitor.io
          when Socket
            if monitor.writable?
              begin
                socket.connect_nonblock Socket.sockaddr_in(remote_port, remote_addr)
              rescue Errno::EISCONN
                # SUCCESS! Since Ruby is crazy we discover we're successful via an exception
              end
            end
          end
        end
        socket.write_nonblock(GOGOBOLT)
        socket.write_nonblock(bolt_versions(*versions))

        @data = nil
        begin
          @data = socket.read_nonblock(16384)
        rescue IO::WaitReadable
          monitor = selector.register(socket, :r)
          monitor.value = proc do
            @data = socket.read_nonblock(16384)
          end
        end
        Concurrent::Promises.future do
          selector.select do |monitor|
            monitor.value.call
          end
          @data.unpack('C*').reverse.map(&:to_s).join('.')
        end
      end

      def driver(uri, auth_token = nil, **config)
        check do
          uri = URI(uri)
          config = Config.new(**config)

          Internal::DriverFactory.new_instance(
            uri,
            auth_token || org.neo4j.driver.AuthTokens.none,
            config.java_config.routing_settings,
            config[:max_transaction_retry_time],
            config,
            config[:security_settings].create_security_plan(uri.scheme)
          )
        end
      end

      def routing_driver(routing_uris, auth_toke, **config)
        assert_routing_uris(routing_uris)
        log = Config.new(**config)[:logger]

        routing_uris.each do |uri|
          driver = driver(uri, auth_toke, **config)
          begin
            return driver.tap(&:verify_connectivity)
          rescue Exceptions::ServiceUnavailableException => e
            log.warn { "Unable to create routing driver for URI: #{uri}\n#{e}" }
            close_driver(driver, uri, log)
          rescue Exception => e
            close_driver(driver, uri, log)
            raise e
          end
        end

        raise Exceptions::ServiceUnavailableException, 'Failed to discover an available server'
      end

      private

      def bolt_version(version)
        pad(version.split(/[.\-]/).map(&:to_i), 4).reverse
      end

      def bolt_versions(*versions)
        pad(versions[0..3].map(&method(:bolt_version)).flatten, 16).pack('C*')
      end

      def pad(arr, n)
        arr + [0] * [0, n - arr.size].max
      end

      def close_driver(driver, uri, log)
        driver.close
      rescue StandardError => close_error
        log.warn { "Unable to close driver towards URI: #{uri}\n#{close_error}" }
      end

      def assert_routing_uris(uris)
        uris.find { |uri| URI(uri).scheme != Neo4j::Driver::Internal::Scheme::NEO4J_URI_SCHEME }&.tap do |uri|
          raise ArgumentError, "Illegal URI scheme, expected '#{Internal::Scheme::NEO4J_URI_SCHEME}' in '#{uri}'"
        end
      end
    end
  end
end
