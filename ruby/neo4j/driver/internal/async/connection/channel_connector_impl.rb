module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class ChannelConnectorImpl
          def initialize(connection_settings, security_plan, logger, clock, routing_context, pipeline_builder = ChannelPipelineBuilderImpl.new, &domain_name_resolver)
            @user_agent = connection_settings.user_agent
            @auth_token = self.class.require_valid_auth_token(connection_settings.auth_token)
            @routing_context = routing_context
            @connect_timeout_millis = connection_settings.connect_timeout_millis
            @security_plan = Validator.require_non_nil!(security_plan)
            @pipeline_builder = pipeline_builder
            @logger = Validator.require_non_nil!(logger)
            @clock = Validator.require_non_nil!(clock)
            @domain_name_resolver = Validator.require_non_nil!(domain_name_resolver)
          end

          def connect(address)
            socket_host = (@domain_name_resolver.call(address.connection_host).first.ip_address rescue nil) ||
              bracketless(address.connection_host)

            endpoint = ::Async::IO::Endpoint.tcp(socket_host, address.port)
            if @security_plan.requires_encryption?
              endpoint = ::Async::IO::SSLEndpoint.new(endpoint, ssl_context: @security_plan.ssl_context,
                                                    hostname: address.host)
            end
            channel_connected = endpoint.connect

            # install_channel_connected_listeners(address, channel_connected, handshake_completed)
            # install_handshake_completed_listeners(handshake_completed, connection_initialized)

            channel_connected
          rescue Errno::ECONNREFUSED => e
            raise Exceptions::ServiceUnavailableException, e.message
          end

          def initialize_channel(channel, protocol)
            protocol.initialize_channel(channel, @user_agent, @auth_token, @routing_context)
          end

          private

          def bracketless(host)
            host.delete_prefix('[').delete_suffix(']')
          end

          def install_channel_connected_listeners(address, channel_connected, handshake_completed)
            pipeline = channel_connected.channel.pipeline

            # add timeout handler to the pipeline when channel is connected. it's needed to limit amount of time code
            # spends in TLS and Bolt handshakes. prevents infinite waiting when database does not respond
            channel_connected.add_listener { pipeline.add_first(Inbound::ConnectTimeoutHandler.new(@connect_timeout_millis)) }

            # add listener that sends Bolt handshake bytes when channel is connected
            channel_connected.add_listener(ChannelConnectedListener.new(address, @pipeline_builder, handshake_completed, @logger))
          end

          def install_handshake_completed_listeners(handshake_completed, connection_initialized)
            pipeline = handshake_completed.channel.pipeline

            # remove timeout handler from the pipeline once TLS and Bolt handshakes are completed. regular protocol
            # messages will flow next and we do not want to have read timeout for them
            handshake_completed.add_listener { pipeline.remove(Inbound::ConnectTimeoutHandler.java_class) }

            # add listener that sends an INIT message. connection is now fully established. channel pipeline if fully
            # set to send/receive messages for a selected protocol version
            handshake_completed.add_listener(HandshakeCompletedListener.new(@user_agent, @auth_token, @routing_context, connection_initialized))
          end

          class << self
            def require_valid_auth_token(token)
              if token.is_a? Internal::Security::InternalAuthToken
                token
              else
                raise Exceptions::ClientException, "Unknown authentication token, `#{token}`. Please use one of the supported tokens from `#{AuthTokens.class}`."
              end
            end
          end
        end
      end
    end
  end
end
