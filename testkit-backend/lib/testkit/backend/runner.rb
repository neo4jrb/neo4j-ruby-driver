module Testkit
  module Backend
    class Runner
      def initialize(port)
        @selector = NIO::Selector.new

        @server = TCPServer.new(port)
        puts "Listening on #{}:#{port}"

        monitor = @selector.register(@server, :r)
        monitor.value = proc { accept }
      end

      def run
        loop do
          @selector.select { |monitor| monitor.value.call }
        end
      end

      def accept
        socket = @server.accept
        _, port, host = socket.peeraddr
        puts "*** #{host}:#{port} connected"
        # handle_client(socket)

        command_processor = CommandProcessor.new(socket)
        monitor = @selector.register(socket, :r)
        monitor.value = proc { handle_client(socket, command_processor) }
      end

      def handle_client(client_socket, command_processor)
        puts "handling client"
        command_processor.process
        puts "finished handling client"
      rescue StandardError => e

        _, port, host = client_socket.peeraddr
        puts "*** #{host}:#{port} disconnected"

        @selector.deregister(client_socket)
        client_socket.close
        puts e
        puts e.backtrace
        # raise e
      end
    end
  end
end