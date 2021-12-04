module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class NettyChannelInitializer < io.netty.channel.ChannelInitializer
          attr_reader :address, :security_plan, :connect_timeout_millis, :clock, :logging

          def initialize(address, security_plan, connect_timeout_millis, clock, logging)
            @address = address
            @security_plan = security_plan
            @connect_timeout_millis = connect_timeout_millis
            @clock = clock
            @logging = logging
          end

          def init_channel(channel)
            if security_plan.requires_encryption?
              ssl_handler = create_ssl_handler
              channel.pipeline.add_first(ssl_handler)
            end

            update_channel_attributes(channel)
          end

          private

          def create_ssl_handler
            ssl_engine = create_ssl_engine
            ssl_handler = io.netty.handler.ssl.SslHandler.new(ssl_engine)
            ssl_handler.set_handshake_timeout_millis(connect_timeout_millis)
            ssl_handler
          end

          def create_ssl_engine
            ssl_context = security_plan.ssl_context
            ssl_engine = ssl_context.create_ssl_engine(address.host, address.port)
            ssl_engine.set_use_client_mode(true)

            if security_plan.requires_hostname_verification
              ssl_parameters = ssl_engine.get_ssl_parameters
              ssl_parameters.set_endpoint_identification_algorithm('HTTPS')
              ssl_engine.set_ssl_parameters(ssl_parameters)
            end
            ssl_engine
          end

          def update_channel_attributes(channel)
            ChannelAttributes.set_server_address(channel, address)
            ChannelAttributes.set_creation_timestamp(channel, clock.millis)
            ChannelAttributes.set_message_dispatcher(channel, Inbound::InboundMessageDispatcher.new(channel, logging))
          end
        end
      end
    end
  end
end
