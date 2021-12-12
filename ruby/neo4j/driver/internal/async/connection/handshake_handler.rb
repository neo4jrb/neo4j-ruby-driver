module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class HandshakeHandler < org.neo4j.driver.internal.shaded.io.netty.handler.codec.ReplayingDecoder
          attr_reader :pipeline_builder, :handshake_completed_promise, :logging
          attr_accessor :failed, :log, :error_log

          def initialize(pipeline_builder, handshake_completed_promise, logging)
            @pipeline_builder = pipeline_builder
            @handshake_completed_promise = handshake_completed_promise
            @logging = logging
            @failed, @log, @error_log = nil
          end

          def handler_added(ctx)
            log = Logging::ChannelActivityLogger.new(ctx.channel, logging, get_class)
            error_log = Logging::ChannelErrorLogger.new(ctx.channel, logging)
          end

          def handler_removed0(ctx)
            failed = false
            log = nil
          end

          def channel_inactive(ctx)
            log.debug('Channel is inactive')

            unless failed
              # channel became inactive while doing bolt handshake, not because of some previous error
              error = Util::ErrorUtil.new_connection_terminated_error
              fail(ctx, error)
            end
          end

          def exception_caught(ctx, error)
            if failed
              error_log.trace_or_debug('Another fatal error occurred in the pipeline', error)
            else
              failed = true
              cause = transform_error(error)
              fail(ctx, cause)
            end
          end

          def decode(ctx, _in, out)
            server_suggested_version = Messaging::BoltProtocolVersion.from_raw_bytes(_in.read_int)
            log.debug("S: [Bolt Handshake] #{server_suggested_version}")

            # this is a one-time handler, remove it when protocol version has been read
            ctx.pipeline.remove

            protocol = protocol_for_version(server_suggested_version)
            if !protocol.nil?
              protocol_selected(server_suggested_version, protocol.create_message_format, ctx)
            else
              handle_unknown_suggested_protocol_version(server_suggested_version, ctx)
            end
          end

          private

          def protocol_for_version(version)
            begin
              Messaging::BoltProtocol(version)
            rescue Neo4j::Driver::Exception::ClientException => e
              nil
            end
          end

          def protocol_selected(version, message_format, ctx)
            ChannelAttributes.set_protocol_version(ctx.channel, version)
            pipeline_builder.build(message_format, ctx.pipeline, logging)
            handshake_completed_promise.set_success
          end

          def handle_unknown_suggested_protocol_version(version, ctx)
            if BoltProtocolUtil::NO_PROTOCOL_VERSION.eql?(version)
              fail(ctx, protocol_no_supported_by_server_error)
            elsif Messaging::BoltProtocolVersion.is_http(version)
              fail(ctx, http_endpoint_error)
            else
              fail(ctx, protocol_no_supported_by_driver_error(version))
            end
          end

          def fail(ctx, error)
            ctx.close.add_listener(->(_future) { handshake_completed_promise.try_failure(error) })
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
              error = error.get_cause if error.kind_of?(org.neo4j.driver.internal.shaded.io.netty.handler.codec.DecoderException) && !error.get_cause.nil?
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
