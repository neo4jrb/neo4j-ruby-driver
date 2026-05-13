module TestkitBackend
    class CommandProcessor
      MAX_LOG_BYTES = 512
      REQUEST_BEGIN = "#request begin"
      REQUEST_END = "#request end"

      def initialize(socket)
        @socket = socket
        @buffer = String.new
        @closed = false
        @debug = ENV["TESTKIT_DEBUG"] == "1"
      end

      def process(blocking: false)
        while (var = read_chunk(blocking))
          log_chunk(blocking ? "blocking:" : "nonblocking:", var)
          @buffer << var
          if (request_begin = find_request_begin) && (request_end = find_request_end(request_begin))
            to_process = @buffer[request_begin...request_end[:start]]
            @buffer = @buffer[(request_end[:line_end] + 1)..-1] || ""
            return process_request(to_process)
          end
        end
      rescue Errno::EBADF, Errno::EPIPE, IOError => e
        warn "socket read failed: #{e.class}: #{e.message}"
        nil
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

        write_all(payload)
      end

      def to_testkit(name, object)
        { name: name.to_s, data: { id: object.object_id } }
      end

      def response(message)
        "#response begin\n#{JSON.dump(message)}\n#response end\n".tap { |var| log_chunk("written:", var) } if message
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
