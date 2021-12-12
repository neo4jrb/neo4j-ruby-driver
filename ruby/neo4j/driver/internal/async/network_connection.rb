module Neo4j::Driver
  module Internal
    module Async
      class NetworkConnection
        attr_reader :server_agent, :server_address, :server_version, :protocol

        def initialize(channel, channel_pool, clock, metrics_listener, logging)
          @log = logging.get_log(self)
          @channel = channel
          @message_dispatcher = Connection::ChannelAttributes.message_dispatcher(channel)
          @server_agent = Connection::ChannelAttributes.server_agent(channel)
          @server_address = Connection::ChannelAttributes.server_address(channel)
          @server_version = Connection::ChannelAttributes.server_version(channel)
          @protocol = Messaging::BoltProtocol.for_channel(channel)
          @channel_pool = channel_pool
          @release_future = java.util.concurrent.CompletableFuture.new
          @clock = clock
          @metrics_listener = metrics_listener
          @in_use_event = metrics_listener.create_listener_event
          @connection_read_timeout = Connection::ChannelAttributes.connection_read_timeout(channel) || nil
          metrics_listener.after_connection_created(Connection::ChannelAttributes.pool_id(channel), @in_use_event)
          @status = Status::OPEN
        end

        def is_open?
          @status.get == Status::OPEN
        end

        def enable_auto_read
          set_auto_read(true) if is_open?
        end

        def disable_auto_read
          set_auto_read(false) if is_open?
        end

        def flush
          flush_in_event_loop if verify_open(nil, nil)
        end

        def write(message1, handler1, message2 = nil, handler2 = nil)
          if message2.nil? && handler2.nil?
            write_message_in_event_loop(message1, handler1, false) if verify_open(handler1, nil)
          else
            write_messages_in_event_loop(message1, handler1, message2, handler2, false) if verify_open(handler1, handler2)
          end
        end

        def write_and_flush(message1, handler1, message2 = nil, handler2 = nil)
          if message2.nil? && handler2.nil?
            write_message_in_event_loop(message1, handler1, true) if verify_open(handler1, nil)
          else
            write_messages_in_event_loop(message1, handler1, message2, handler2, true) if verify_open(handler1, handler2)
          end
        end

        def reset
          result = java.util.concurrent.CompletableFuture.new
          handler = Handlers::ResetResponseHandler.new(@message_dispatcher, result)
          write_reset_message_if_needed(handler, true)
          result
        end

        def release
          if @status.compare_and_set(Status::OPEN, Status::RELEASED)
            handler = Handlers::ChannelReleasingResetResponseHandler.new(@channel, @channel_pool, @message_dispatcher, @clock, @release)
            write_reset_message_if_needed(handler, false)
            @metrics_listener.after_connection_released(Connection::ChannelAttributes.pool_id(@channel), @in_use_event)
          end
          @release_future
        end

        def terminate_and_release(reason)
          if @status.compare_and_set(Status::OPEN, Status::TERMINATED)
            Connection::ChannelAttributes.set_termination_reason(@channel, reason)
            Util::Futurs.as_completion_stage(@channel.close).exceptionally(-> (_throwable) { nil }).then_compose(-> (_ignored) { @channel_pool.release(@channel) }).when_complete do |_ignored, _throwable|
              @release_future.complete(nil)
              @metrics_listener.after_connection_released(Connection::ChannelAttributes.pool_id(@channel), @in_use_event)
            end
          end
        end

        private

        def write_reset_message_if_needed(reset_handler, is_session_reset)
          @channel.event_loop.execute do
            if is_session_reset && !is_open?
              reset_handler.on_success(java.util.Collections.empty_map)
            else
              # auto-read could've been disabled, re-enable it to automatically receive response for RESET
              set_auto_read(true)
              @message_dispatcher.enqueue(reset_handler)
              @channel.write_and_flush(Messaging::Request::ResetMessage::RESET).add_listener(-> (_future) { register_connection_read_timeout(@channel) })
            end
          end
        end

        def flush_in_event_loop
          @channel.event_loop.execute do
            @channel.flush
            register_connection_read_timeout(@channel)
          end
        end

        def write_message_in_event_loop(message, handler, flush)
          @channel.event_loop.execute do
            @message_dispatcher.enqueue(handler)

            if flush
              @channel.write_and_flush(message).add_listener(-> (_future) { register_connection_read_timeout(@channel) })
            else
              @channel.write(message, @channel.void_promise)
            end
          end
        end

        def write_messages_in_event_loop(message1, handler1, message2, handler2, flush)
          @channel.event_loop.execute do
            @message_dispatcher.enqueue(handler1)
            @message_dispatcher.enqueue(handler2)

            @channel.write(message1, channel.void_promise)

            if flush
              @channel.write_and_flush(message2).add_listener(-> (_future) { register_connection_read_timeout(@channel) })
            else
              @channel.write(message2, @channel.void_promise)
            end
          end
        end

        def set_auto_read(value)
          @channel.config.set_auto_read(value)
        end

        def verify_open(handler1, handler2)
          connection_status = @status.get

          case connection_status
          when 'open'
            true
          when 'released'
            error = Neo4j::Driver::Exceptions::IllegalStateException.new("Connection has been released to the pool and can't be used")

            handler1.on_failure(error) unless handler1.nil?

            handler2.on_failure(error) unless handler2.nil?

            false
          when 'terminated'
            terminated_error = Neo4j::Driver::Exceptions::IllegalStateException.new("Connection has been terminated and can't be used")

            handler1.on_failure(terminated_error) unless handler1.nil?

            handler2.on_failure(terminated_error) unless handler2.nil?

            false
          else
            raise Neo4j::Driver::Exceptions::IllegalStateException.new("Unknown status: #{connection_status}")
          end
        end

        def register_connection_read_timeout(channel)
          if !channel.event_loop.in_event_loop
            raise Neo4j::Driver::Exceptions::IllegalStateException.new('This method may only be called in the EventLoop')
          end

          if !@connection_read_timeout.nil? && @connection_read_timeout_handler.nil?
            connection_read_timeout_handler = Inbound::ConnectionReadTimeoutHandler.new(@connection_read_timeout, java.util.concurrent.TimeUnit::SECONDS)
            channel.pipeline.add_first(connection_read_timeout_handler)
            @log.debug('Added ConnectionReadTimeoutHandler')

            @message_dispatcher.set_before_last_handler_hook do |message_type|
              channel.pipeline.remove(connection_read_timeout_handler)
              connection_read_timeout_handler = nil
              @message_dispatcher.set_before_last_handler_hook(nil)
              log.debug('Removed ConnectionReadTimeoutHandler')
            end
          end
        end

        class Status
          OPEN = 'open'
          RELEASED = 'released'
          TERMINATED = 'terminated'
        end
      end
    end
  end
end
