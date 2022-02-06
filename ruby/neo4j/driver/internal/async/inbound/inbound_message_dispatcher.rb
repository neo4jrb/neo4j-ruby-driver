module Neo4j::Driver
  module Internal
    module Async
      module Inbound
        class InboundMessageDispatcher
          attr_reader :fatal_error_occurred, :current_error, :log, :error_log
          # Visible for testing
          attr_reader :auto_read_managing_handler

          def initialize(channel, logging)
            @handlers = []
            @channel = Validator.require_non_nil!(channel)
            @log = Logging::ChannelActivityLogger.new(channel, logging, self.class)
            @error_log = Logging.ChannelErrorLogger.new(channel, logging)
          end

          def enqueue(handler)
            if fatal_error_occurred
              handler.on_failure(current_error)
            else
              @handlers << handler
              update_auto_read_managing_handler_if_needed(handler)
            end
          end

          def set_before_last_handler_hook(before_last_handler_hook)
            unless @channel.event_loop.in_event_loop
              raise Neo4j::Driver::Exceptions::IllegalStateException, 'This method may only be called in the EventLoop'
            end
            @before_last_handler_hook = before_last_handler_hook
          end

          def queued_handlers_count
            @handlers.size
          end

          def handle_success_message(meta)
            log.debug("S: SUCCESS #{meta}")
            invoke_before_last_handler_hook(HandlerHook::SUCCESS)
            handler = remove_handler
            handler.on_success(meta)
          end

          def handle_record_message(fields)
            if log.debug_enabled?
              log.debug("S: RECORD #{fields}")
            end

            handler = @handlers.first
            if handler.nil?
              raise Neo4j::Driver::Exceptions::IllegalStateException, "No handler exists to handle RECORD message with fields #{fields}"
            end

            handler.on_record(fields)
          end

          def handle_failure_message(code, message)
            log.debug("S: FAILURE #{code} '#{message}'")
            current_error = Util::ErrorUtil.new_neo4j_error(code, message)

            # we should not continue using channel after a fatal error
            # fire error event back to the pipeline and avoid sending RESET
            return @channel.pipeline.fire_exception_caught(current_error) if Util::ErrorUtil.fatal?(current_error)

            if current_error.kind_of?(Neo4j::Driver::Exceptions::AuthorizationExpiredException)
              Connection::ChannelAttributes.authorization_state_listener(@channel).on_expired(current_error, @channel)
            else
              # write a RESET to "acknowledge" the failure
              enqueue(ResetResponseHandler.new(self))
              @channel.write_and_flush(RESET, @channel.void_promise)
            end

            invoke_before_last_handler_hook(HandlerHook::FAILURE)
            handler = remove_handler
            handler.on_failure(current_error)
          end

          def handle_ignored_message
            log.debug('S: IGNORED')
            handler = remove_handler

            if current_error
              error = current_error
            else
              log.warn("Received IGNORED message for handler #{handler} but error is missing and RESET is not in progress. Current handlers #{@handlers}")
              error = Neo4j::Driver::Exceptions::ClientException('Database ignored the request')
            end

            handler.on_failure(error)
          end

          def handle_channel_inactive(cause)
            # report issue if the connection has not been terminated as a result of a graceful shutdown request from its
            # parent pool
            if !@gracefully_closed
              handle_channel_error(cause)
            else
              @channel.close
            end
          end

          def handle_channel_error(error)
            if current_error
              # we already have an error, this new error probably is caused by the existing one, thus we chain the new error on this current error
              Util::ErrorUtil.add_suppressed(current_error, error)
            else
              @current_error = error
            end

            @fatal_error_occurred = true

            while !@handlers.empty?
              handler = remove_handler
              handler.on_failure(current_error)
            end

            error_log.trace_or_debug('Closing channel because of a failure', error)
            @channel.close
          end

          def clear_current_error
            @current_error = nil
          end

          def prepare_to_close_channel
            @gracefully_closed = true
          end

          private

          def remove_handler
            handler = @handlers.drop(1)

            if handler == auto_read_managing_handler
              # the auto-read managing handler is being removed
              # make sure this dispatcher does not hold on to a removed handler
              update_auto_read_managing_handler(nil)
            end
            handler
          end

          def update_auto_read_managing_handler_if_needed(handler)
            if handler.can_manage_auto_read
              update_auto_read_managing_handler(handler)
            end
          end

          def update_auto_read_managing_handler(new_handler)
            if auto_read_managing_handler

              # there already exists a handler that manages channel's auto-read
              # make it stop because new managing handler is being added and there should only be a single such handler
              auto_read_managing_handler.disable_auto_read_management

              # restore the default value of auto-read
              @channel.config.set_auto_read(true)
            end

            @auto_read_managing_handler = new_handler
          end

          def invoke_before_last_handler_hook(message_type)
            @before_last_handler_hook&.run(message_type) if handlers.size == 1
          end

          module HandlerHook
            SUCCESS = :success
            FAILURE = :failure
          end
        end
      end
    end
  end
end
