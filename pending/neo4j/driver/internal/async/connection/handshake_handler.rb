module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class HandshakeHandler #< org.neo4j.driver.internal.shaded.io.netty.handler.codec.ReplayingDecoder
          def initialize(pipeline_builder, handshake_completed_promise, logger)
            @pipeline_builder = pipeline_builder
            @handshake_completed_promise = handshake_completed_promise
            @logger = logger
          end

          def handler_added(ctx)
            @log = Logging::ChannelActivityLogger.new(ctx.channel, @logger, self.class)
            @error_log = Logging::ChannelErrorLogger.new(ctx.channel, @logger)
          end

          def handler_removed0(ctx)
            @failed = false
            @log = nil
          end

          def channel_inactive(ctx)
            @log.debug('Channel is inactive')

            unless @failed
              # channel became inactive while doing bolt handshake, not because of some previous error
              error = Util::ErrorUtil.new_connection_terminated_error
              fail(ctx, error)
            end
          end

          def exception_caught(ctx, error)
            if @failed
              @error_log.debug('Another fatal error occurred in the pipeline', error)
            else
              @failed = true
              cause = transform_error(error)
              fail(ctx, cause)
            end
          end

          def decode(ctx, in_, _out)
            server_suggested_version = Messaging::BoltProtocolVersion.from_raw_bytes(in_.read_int)
            @log.debug("S: [Bolt Handshake] #{server_suggested_version}")

            # this is a one-time handler, remove it when protocol version has been read
            ctx.pipeline.remove(self)

            protocol = protocol_for_version(server_suggested_version)
            if protocol
              protocol_selected(server_suggested_version, protocol.create_message_format, ctx)
            else
              handle_unknown_suggested_protocol_version(server_suggested_version, ctx)
            end
          end

          private

          def protocol_for_version(version)
            Messaging::BoltProtocol(version)
          rescue Neo4j::Driver::Exception::ClientException
            nil
          end

          def protocol_selected(version, message_format, ctx)
            ChannelAttributes.set_protocol_version(ctx.channel, version)
            pipeline_builder.build(message_format, ctx.pipeline, @logger)
            handshake_completed_promise.set_success
          end

          def handle_unknown_suggested_protocol_version(version, ctx)
            if BoltProtocolUtil::NO_PROTOCOL_VERSION == version
              fail(ctx, protocol_no_supported_by_server_error)
            elsif Messaging::BoltProtocolVersion.http?(version)
              fail(ctx, http_endpoint_error)
            else
              fail(ctx, protocol_no_supported_by_driver_error(version))
            end
          end

          def fail(ctx, error)
            ctx.close.add_listener { @handshake_completed_promise.try_failure(error) }
          end

          class << self
            def protocol_no_supported_by_server_error
              raise Neo4j::Driver::Exception::ClientException, 'The server does not support any of the protocol versions supported by this driver. Ensure that you are using driver and server versions that are compatible with one another.'
            end

            def http_endpoint_error
              raise Neo4j::Driver::Exception::ClientException, 'Server responded HTTP. Make sure you are not trying to connect to the http endpoint (HTTP defaults to port 7474 whereas BOLT defaults to port 7687)'
            end

            def protocol_no_supported_by_driver_error(suggested_protocol_version)
              raise Neo4j::Driver::Exception::ClientException, "Protocol error, server suggested unexpected protocol version: #{suggested_protocol_version}"
            end

            def transform_error(error)
              # unwrap the DecoderException if it has a cause
              error = error.cause if error.is_a?(org.neo4j.driver.internal.shaded.io.netty.handler.codec.DecoderException) && error.cause
              case error
              when Neo4j::Driver::Exception::ServiceUnavailableException
                error
              when javax.net.ssl.SSLHandshakeException
                Neo4j::Driver::Exception::SecurityException.new('Failed to establish secured connection with the server', error)
              else
                Neo4j::Driver::Exception::ServiceUnavailableException('Failed to establish connection with the server', error)
              end
            end
          end
        end
      end
    end
  end
end