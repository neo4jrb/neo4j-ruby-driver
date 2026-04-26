# frozen_string_literal: true

# Testkit backend for the Neo4j Ruby driver.
#
# Testkit (https://github.com/neo4j-drivers/testkit) is the shared
# integration/conformance test suite for Neo4j drivers. Its Python test
# runner talks to a language-specific "backend" process over a TCP
# socket using a simple framed JSON protocol. This file is the entry
# point for the Ruby backend.
#
# Run it standalone for local development:
#   bundle exec ruby testkit-backend/backend.rb
#
# Then from a testkit clone:
#   export TEST_DRIVER_NAME=ruby
#   export TEST_NEO4J_HOST=localhost
#   python3 -m unittest tests.neo4j.test_session_run

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'neo4j/driver'

require 'json'
require 'securerandom'
require 'socket'
require 'zeitwerk'

module TestkitBackend; end

loader = Zeitwerk::Loader.new
loader.push_dir(__dir__, namespace: TestkitBackend)
loader.setup

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
    rescue StandardError => e
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
      @registry = Registry.new
    end

    def run
      while (request = read_request)
        write_response(Request.dispatch(request, @registry))
      end
    end

    private

    def write_response(response)
      @socket.write("#{RESPONSE_BEGIN}\n#{JSON.generate(response.to_payload)}\n#{RESPONSE_END}\n")
      @socket.flush
    end

    def read_request
      line = read_line
      line = read_line while line && line != REQUEST_BEGIN
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
      @socket.gets&.chomp
    end
  end
end

TestkitBackend::Server.new.run if $PROGRAM_NAME == __FILE__
