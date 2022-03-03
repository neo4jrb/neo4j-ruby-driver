module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class BootstrapFactory
          class << self
            def new_bootstrap(thread_count: nil,
                              event_loop_group: EventLoopGroupFactory.new_event_loop_group(thread_count))
              Ione::Io::IoReactor.new
              # Io::Bootstrap.new.tap do |bootstrap|
              #   bootstrap.group = event_loop_group
              #   bootstrap.channel(EventLoopGroupFactory.channel_class)
                # bootstrap.option(org.neo4j.driver.internal.shaded.io.netty.channel.ChannelOption::SO_KEEPALIVE, true)
                # bootstrap.option(org.neo4j.driver.internal.shaded.io.netty.channel.ChannelOption::SO_REUSEADDR, true)
              # end
            end
          end
        end
      end
    end
  end
end
