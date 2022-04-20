module Neo4j::Driver
  module Internal
    module Async
      module Outbound
        class OutboundMessageHandler
          NAME = self.class.name

          def initialize(output, message_format, logger)
            @output = output
            @writer = message_format.new_writer(output)
            @log = logger
          end

          def handler_added(ctx)
            @log = Logging::ChannelActivityLogger.new(ctx.channel, @log, self.class)
          end

          def handler_removed(ctx)
            @log = nil
          end

          def encode(msg)
            @log.debug("C: #{msg}")

            @output.start
            begin
              @writer.write(msg)
            ensure
              @output.stop
            end

            @output.write_message_boundary
            # @log.debug( "C: #{}") if @log.debug_enabled?
          end
        end
      end
    end
  end
end
