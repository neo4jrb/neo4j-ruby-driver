RSpec.describe Testkit::Backend::Runner do
  # include_context Async::RSpec::Reactor

  def echo_client(server_address, data)
    Async do |task|
      Async::IO::Socket.connect(server_address) do |peer|
        peer.write(data)
        # peer.close_write

        message = peer.read(10)

        puts "Sent #{data}, got response: #{message}"
      end
    end
  end

  it "responds with reverse string" do
    Async do
      # server = described_class.start
      tasks = 10.times.map do |i|
        echo_client(Async::IO::Address.tcp('localhost', 9876), "Hello World #{i}")
      end
      tasks.each(&:wait)
      # server.stop
    end
  end
end
