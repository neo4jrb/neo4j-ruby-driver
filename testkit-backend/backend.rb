# frozen_string_literal: true

# Testkit backend for the Neo4j Ruby driver.
#
# Testkit (https://github.com/neo4j-drivers/testkit) is the shared
# integration/conformance test suite for Neo4j drivers. Its Python test
# runner talks to a language-specific "backend" process over a TCP
# socket using a simple framed JSON protocol. This file implements that
# backend for the Ruby driver.
#
# Run it standalone for local development:
#   bundle exec ruby testkit-backend/backend.rb
#
# Then from a testkit clone:
#   export TEST_NEO4J_HOST=localhost
#   python3 -m unittest tests.neo4j.test_session_run

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'neo4j/driver'

require 'json'
require 'securerandom'
require 'socket'

require_relative 'cypher'
require_relative 'dispatcher'

module TestkitBackend
  class Server
    DEFAULT_HOST = ENV.fetch('TEST_BACKEND_HOST', '0.0.0.0')
    DEFAULT_PORT = Integer(ENV.fetch('TEST_BACKEND_PORT', 9876))

    def initialize(host: DEFAULT_HOST, port: DEFAULT_PORT)
      @host = host
      @port = port
    end

    def run
      tcp = TCPServer.new(@host, @port)
      warn "Testkit backend listening on #{@host}:#{@port}"

      loop do
        client = tcp.accept
        Thread.new(client) { |sock| handle(sock) }
      end
    end

    private

    def handle(socket)
      Connection.new(socket).run
    rescue => e
      warn "Unhandled backend error: #{e.class}: #{e.message}"
      warn e.backtrace.first(10).join("\n")
    ensure
      socket.close rescue nil
    end
  end

  class Connection
    REQUEST_BEGIN = '#request begin'
    REQUEST_END = '#request end'
    RESPONSE_BEGIN = '#response begin'
    RESPONSE_END = '#response end'

    def initialize(socket)
      @socket = socket
      @dispatcher = Dispatcher.new(self)
    end

    def run
      while (request = read_request)
        response = @dispatcher.dispatch(request)
        write_response(response) if response
      end
    end

    def write_response(response)
      payload = JSON.generate(response)
      @socket.write("#{RESPONSE_BEGIN}\n")
      @socket.write("#{payload}\n")
      @socket.write("#{RESPONSE_END}\n")
      @socket.flush
    end

    private

    def read_request
      # Skip until we see the opening sentinel (blank lines allowed between messages).
      line = read_line
      while line && line != REQUEST_BEGIN
        return nil if line.nil?
        line = read_line
      end
      return nil unless line

      body = +''
      loop do
        line = read_line
        return nil if line.nil?
        break if line == REQUEST_END

        body << line << "\n"
      end

      JSON.parse(body)
    end

    def read_line
      raw = @socket.gets
      raw&.chomp
    end
  end
end

if $PROGRAM_NAME == __FILE__
  TestkitBackend::Server.new.run
end
