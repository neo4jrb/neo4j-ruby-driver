module TestkitBackend
    class CommandProcessor
      MAX_LOG_BYTES = 512
      REQUEST_BEGIN = "#request begin"
      REQUEST_END = "#request end"

      # Backend->frontend callback replies. The driver invokes the matching
      # callbacks (auth-token manager, resolver, bookmark manager, …) from its
      # own threads — for a routing driver that's Netty I/O threads, and more
      # than one can be in flight at once. The reader routes these to the
      # waiting callback instead of treating them as new top-level requests.
      COMPLETION_NAMES = %w[
        AuthTokenManagerGetAuthCompleted
        AuthTokenManagerHandleSecurityExceptionCompleted
        BasicAuthTokenProviderCompleted
        BearerAuthTokenProviderCompleted
        BookmarksSupplierCompleted
        BookmarksConsumerCompleted
        ClientCertificateProviderCompleted
        DomainNameResolutionCompleted
        ResolverResolutionCompleted
      ].to_set.freeze

      def initialize(socket)
        @socket = socket
        @buffer = String.new
        @closed = false
        @debug = ENV["TESTKIT_DEBUG"] == "1"
        # One reader thread owns the socket; everything else communicates
        # through these. @io_mutex guards every write and the FIFO waiter
        # list — never held across a blocking wait, so it can't deadlock.
        @io_mutex = Mutex.new
        @waiters = []
        @requests = Queue.new
      end

      # Sole socket reader. Frames each message and routes it: a callback
      # reply goes to the oldest waiting callback (FIFO is correct because
      # writes are serialised, so request order == reply order); anything
      # else is a request for the executor to run.
      def start_reader
        @reader = Thread.new do
          while (raw = read_message)
            if COMPLETION_NAMES.include?(JSON.parse(raw, symbolize_names: true)[:name])
              (@io_mutex.synchronize { @waiters.shift })&.push(raw)
            else
              @requests.push(raw)
            end
          end
        ensure
          # Unblock any callback still waiting on a reply — the connection is
          # gone, so its reply will never arrive (a closed Thread::Queue#pop
          # returns nil). Otherwise that driver thread hangs forever.
          @io_mutex.synchronize do
            @waiters.each(&:close)
            @waiters.clear
          end
          @requests.close
        end
      end

      # Executor loop body: run the next queued request (parse, dispatch to
      # its handler, write the response). Returns falsey when the reader has
      # closed the connection.
      def process_next
        raw = @requests.pop
        return false if raw.nil?

        process_request(raw)
        true
      end

      # Used by the managed-transaction handler to drain nested requests
      # (TransactionRun, RetryablePositive/Negative …) that the frontend
      # sends while the retry function runs. Returns the processed message.
      def next_request
        process_request(@requests.pop)
      end

      # Send a backend->frontend request and block for its reply. Register the
      # waiter and write the request atomically so the FIFO order of waiters
      # matches the order the frontend sees the requests (and thus replies).
      def callback(request_message)
        queue = Thread::Queue.new
        @io_mutex.synchronize do
          raise IOError, "connection closed" if @closed

          @waiters.push(queue)
          write_all(response(request_message))
        end
        raw = queue.pop
        raise IOError, "connection closed while awaiting callback reply" unless raw

        process_request(raw)
      end

      def process_request(request)
        Request.from(JSON.parse(request, symbolize_names: true), self).tap do |message|
          process_response(message.process_request)
        end
      end

      def process_response(response_message)
        return if @closed

        payload = response(response_message)
        return unless payload

        @io_mutex.synchronize { write_all(payload) }
      end

      def to_testkit(name, object)
        { name: name.to_s, data: { id: object.object_id } }
      end

      def response(message)
        "#response begin\n#{JSON.dump(message)}\n#response end\n".tap { |var| log_chunk("written:", var) } if message
      end

      # Read and return one complete framed message (blocking). Reader-thread
      # only, so @buffer needs no locking.
      def read_message
        loop do
          if (request_begin = find_request_begin) && (request_end = find_request_end(request_begin))
            message = @buffer[request_begin...request_end[:start]]
            @buffer = @buffer[(request_end[:line_end] + 1)..-1] || ""
            return message
          end

          chunk = read_chunk(true)
          return nil unless chunk

          log_chunk("blocking:", chunk)
          @buffer << chunk
        end
      rescue Errno::EBADF, Errno::EPIPE, IOError => e
        warn "socket read failed: #{e.class}: #{e.message}"
        nil
      end

      def read_chunk(blocking)
        return nil if @closed || @socket.closed?

        @socket.read_nonblock(4096)
      rescue IO::WaitReadable
        if blocking
          IO.select([@socket])
          retry
        end
        nil
      rescue EOFError
        mark_closed
        nil
      rescue Errno::EBADF, Errno::EPIPE, IOError
        mark_closed
        nil
      end

      def write_all(payload)
        return if @closed

        offset = 0
        while offset < payload.bytesize
          return if @socket.closed?

          begin
            written = @socket.write_nonblock(payload.byteslice(offset..-1))
            offset += written
          rescue IO::WaitWritable
            IO.select(nil, [@socket])
            retry
          end
        end
      rescue Errno::EBADF, Errno::EPIPE, IOError
        mark_closed
      end

      def mark_closed
        return if @closed

        @closed = true
        @socket.close unless @socket.closed?
      rescue Errno::EBADF, Errno::EPIPE, IOError
        nil
      end

      def find_request_begin
        begin_index = @buffer.index(REQUEST_BEGIN)
        return nil unless begin_index

        @buffer = @buffer[begin_index..-1] if begin_index.positive?
        line_end = @buffer.index("\n")
        return nil unless line_end

        line_end + 1
      end

      def find_request_end(start_index)
        end_index = @buffer.index(REQUEST_END, start_index)
        return nil unless end_index

        line_end = @buffer.index("\n", end_index)
        return nil unless line_end

        { start: end_index, line_end: line_end }
      end

      def log_chunk(prefix, data)
        return unless @debug
        return unless data

        if data.bytesize > MAX_LOG_BYTES
          puts "#{prefix} <#{data.byteslice(0, MAX_LOG_BYTES)}... (#{data.bytesize} bytes)>"
        else
          puts "#{prefix} <#{data}>"
        end
      end
    end
end
