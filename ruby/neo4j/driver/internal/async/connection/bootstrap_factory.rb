module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class BootstrapFactory
          class << self
            def new_bootstrap(param)
              event_loop_group = param.is_a?(Integer) ? EventLoopGroupFactory.newEventLoopGroup(param) : param

              bootstrap = io.netty.bootstrap.Bootstrap.new
              bootstrap.group(event_loop_group)
              bootstrap.channel(EventLoopGroupFactory.channel_class)
              bootstrap.option(io.netty.channel.ChannelOption.SO_KEEPALIVE, true)
              bootstrap.option(io.netty.channel.ChannelOption.SO_REUSEADDR, true)
              bootstrap
            end
          end
        end
      end
    end
  end
end