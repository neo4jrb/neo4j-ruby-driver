module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class ChannelConnectorImpl
          attr_reader :user_agent, :auth_token, :security_plan, :logging, :clock, :routing_context, :domain_name_resolver, :pipeline_builder, :connect_timeout_millis

          def initialize(connection_settings, security_plan, logging, clock, routing_context, domain_name_resolver, pipeline_builder = nil)
            @user_agent = connection_settings.user_agent
            @auth_token = require_valid_auth_token(connection_settings.auth_token)
            @routing_context = routing_context
            @connect_timeout_millis = connection_settings.connect_timeout_millis
            @security_plan = java.util.Objects.require_non_null(security_plan)
            @pipeline_builder = pipeline_builder || ChannelPipelineBuilderImpl.new
            @logging = java.util.Objects.require_non_null(logging)
            @clock = java.util.Objects.require_non_null(domain_name_resolver)
            @domain_name_resolver = java.util.Objects.require_non_null(domain_name_resolver)
            @address_resolver_group = NettyDomainNameResolverGroup.new(DOMAIN_NAME_RESOLVER)
          end

          def connect(address, bootstrap)
            bootstrap.option(io.netty.channel.ChannelOption::CONNECT_TIMEOUT_MILLIS, connect_timeout_millis)
            bootstrap.handler(NettyChannelInitializer.new(address, security_plan, connect_timeout_millis, clock, logging))
            bootstrap.resolver(address_resolver_group)

            begin
              socket_address = java.net.InetSocketAddress.new(address_resolver_group)
            rescue
              socket_address = java.net.InetSocketAddress.create_unresolved(address.connection_host, address.port)
            end

            channel_connected = bootstrap.connect(socket_address)

            channel = channel_connected.channel
            handshake_completed = channel.new_promise
            connection_initialized = channel.new_promise

            install_channel_connected_listeners(address, channel_connected, handshake_completed)
            install_handshake_completed_listeners(handshake_completed, connection_initialized)

            connection_initialized
          end

          private

          def install_channel_connected_listeners(address, channel_connected, handshake_completed)
            pipeline = channel_connected.channel.pipeline

            # add timeout handler to the pipeline when channel is connected. it's needed to limit amount of time code
            # spends in TLS and Bolt handshakes. prevents infinite waiting when database does not respond
            channel_connected.add_listener(->(_future) {pipeline.add_first(Inbound::ConnectTimeoutHandler.new(connect_timeout_millis))})

            # add listener that sends Bolt handshake bytes when channel is connected
            channel_connected.add_listener(ChannelConnectedListener.new(address, pipeline_builder, handshake_completed, logging))
          end

          def install_handshake_completed_listeners(handshake_completed, connection_initialized)
            pipeline = handshake_completed.channel.pipeline

            # remove timeout handler from the pipeline once TLS and Bolt handshakes are completed. regular protocol
            # messages will flow next and we do not want to have read timeout for them
            handshake_completed.add_listener(->(_future){pipeline.remove(Inbound::ConnectTimeoutHandler.name)})

            # add listener that sends an INIT message. connection is now fully established. channel pipeline if fully
            # set to send/receive messages for a selected protocol version
            handshake_completed.add_listener(HandshakeCompletedListener.new(user_agent, auth_token, routing_context, connection_initialized))
          end

          class << self
            def require_valid_auth_token(token)
              if token.kind_of?(Security::InternalAuthToken)
                token
              else
                raise Neo4j::Driver::Exceptions::ClientException, "Unknown authentication token, `#{token}`. Please use one of the supported tokens from `#{Neo4j::Driver::AuthTokens.class}`."
              end
            end
          end
        end
      end
    end
  end
end
