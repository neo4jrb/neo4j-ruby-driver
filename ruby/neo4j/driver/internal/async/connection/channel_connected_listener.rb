module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class ChannelConnectedListener < Struct.new(:address, :pipeline_builder, :handshake_completed_promise, :logger)
          # include org.neo4j.driver.internal.shaded.io.netty.channel.ChannelFutureListener
          def operationComplete(future)
            channel = future.channel
            log = Logging::ChannelActivityLogger.new(channel, logger, self.class)

            if future.fulfilled?
              log.debug("Channel #{channel} connected, initiating bolt handshake")

              pipeline = channel.pipeline
              pipeline.add_last(HandshakeHandler.new(pipeline_builder, handshake_completed_promise, logger))
              log.debug("C: [Bolt Handshake] #{BoltProtocolUtil.handshake_string}")
              channel.write_and_flush(BoltProtocolUtil.handshake_buf, channel.void_promise)
            else
              handshake_completed_promise.set_failure(self.class.database_unavailable_error(address, future.cause))
            end
          end

          def self.database_unavailable_error(address, cause)
            Neo4j::Driver::Exceptions::ServiceUnavailableException.new(
              "Unable to connect to #{address}, ensure the database is running and that there is a working network connection to it.",
              cause)
          end
        end
      end
    end
  end
end
