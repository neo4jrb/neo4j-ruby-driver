module TestkitBackend
  class Runner
    def initialize(port)
      @selector = NIO::Selector.new
      @server = TCPServer.new(port)
      puts "Listening on :#{port}"
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

      # One thread per testkit connection. The previous serial loop
      # blocked here until the client disconnected — fine on JRuby
      # native (Java driver is fast) but on JRuby[mri-flavor] the
      # pure-Ruby Bolt path is slow enough that the listen backlog
      # overflows and testkit gets ConnectionRefused on retries.
      Thread.new(socket, host, port) do |sock, h, p|
        cp = CommandProcessor.new(sock)
        while cp.process(blocking: true) do
        end
      rescue StandardError => e
        warn "*** #{h}:#{p} handler crashed: #{e.class}: #{e.message}"
        warn e.backtrace.first(15).join("\n")
      ensure
        close_socket(sock)
      end
    end

    def close_socket(socket)
      return if socket.closed?

      socket.close
    rescue Errno::EBADF, IOError
      nil
    end
  end
end
