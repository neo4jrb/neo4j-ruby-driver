#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("../lib", __dir__)
require "nio"
require "socket"

# Echo server example written with nio4r
class EchoServer
  def initialize(host, port)
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

    monitor = @selector.register(socket, :r)
    monitor.value = proc { read(socket) }
  end

  def read(socket)
    data = socket.read_nonblock(4096)
    puts "data: #{data}"
    response = '#response begin
{"name":"Driver","data":{"id":"0"}}
#response end
'
    puts "response: #{response}"
    socket.puts '#response begin'
    socket.puts '{"name":"Driver","data":{"id":"0"}}'
    socket.puts '#response end'
    # socket.write_nonblock('#response begin\n  {"name":"Driver","data":{"id":"0"}}\n#response end\n')
    # socket.write('#response begin\n  {"name":"Driver","data":{"id":"0"}}\n#response end\n')
    # socket.flush
    # puts "flushed"
    # socket.close_write
  rescue EOFError
    _, port, host = socket.peeraddr
    puts "*** #{host}:#{port} disconnected"

    @selector.deregister(socket)
    socket.close
  end
end

EchoServer.new("0.0.0.0", 9876).run if $PROGRAM_NAME == __FILE__
