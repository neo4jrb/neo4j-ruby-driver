require 'async'
require 'socket'
require 'openssl'

# self-signed cert
key  = OpenSSL::PKey::RSA.new(2048)
cert = OpenSSL::X509::Certificate.new
cert.subject = cert.issuer = OpenSSL::X509::Name.parse('/CN=localhost')
cert.not_before = Time.now; cert.not_after = Time.now + 3600
cert.public_key = key.public_key; cert.serial = 1; cert.version = 2
cert.sign(key, OpenSSL::Digest.new('SHA256'))

tcp = TCPServer.new('127.0.0.1', 0); port = tcp.addr[1]
sctx = OpenSSL::SSL::SSLContext.new; sctx.cert = cert; sctx.key = key
ssl_server = OpenSSL::SSL::SSLServer.new(tcp, sctx)
srv = Thread.new { c = ssl_server.accept; sleep 1.0; c.write('hello'); c.close rescue nil }

out = []
Async do |task|
  r = task.async do
    cctx = OpenSSL::SSL::SSLContext.new; cctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
    s = OpenSSL::SSL::SSLSocket.new(TCPSocket.new('127.0.0.1', port), cctx); s.connect
    t0 = Time.now; data = s.read(5)
    out << "  ssl.read => #{data.inspect} after #{(Time.now - t0).round(2)}s"
  end
  t = task.async { 4.times { |i| sleep 0.2; out << "  tick #{i}" } }
  r.wait; t.wait
end
srv.join
puts "TEST A — SSL read under async scheduler (ticks interleaving the 1s read = SSL yielded):"
puts out

puts "TEST B — cross-thread unblock (main thread submits into a driver-owned reactor):"
work = Thread::Queue.new; done = Thread::Queue.new
rt = Thread.new { Async { |task| task.async { loop { j = work.pop; break if j == :stop; done.push(j * 2) } }.wait } }
work.push(21)                 # pushed from main thread (no scheduler)
res = done.pop
puts "  main pushed 21 -> reactor fiber returned #{res}"
work.push(:stop); rt.join

# TEST C — a fiber cannot be resumed from another thread (why a shared pool
# can't put reader fibers on per-caller reactors): forces a driver-owned reactor.
puts "TEST C — fiber resume across threads:"
f = Fiber.new { Fiber.yield; :done }
f.resume
Thread.new do
  begin
    f.resume
    puts "  resumed cross-thread (unexpected!)"
  rescue => e
    puts "  cross-thread resume -> #{e.class}: #{e.message}"
  end
end.join
