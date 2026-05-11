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

      @command_processor = CommandProcessor.new(socket)
      begin
        while @command_processor.process(blocking: true) do
        end
      rescue StandardError => e
        # Per-connection failure: log and close, but keep the runner
        # alive so other tests can connect.
        warn "*** #{host}:#{port} handler crashed: #{e.class}: #{e.message}"
        warn e.backtrace.first(15).join("\n")
      ensure
        close_socket(socket)
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
