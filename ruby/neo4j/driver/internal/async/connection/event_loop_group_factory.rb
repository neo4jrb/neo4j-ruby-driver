module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class EventLoopGroupFactory
          THREAD_NAME_PREFIX = "Neo4jDriverIO"
          THREAD_PRIORITY = java.lang.Thread.MAX_PRIORITY
          THREAD_IS_DAEMON = true

          class << self
            # Get class of {@link Channel} for {@link Bootstrap#channel(Class)} method.

            # @return class of the channel, which should be consistent with {@link EventLoopGroup}s returned by
            # {@link #newEventLoopGroup(int)}.
            class ChannelClass
              io.netty.channel.socket.nio.NioSocketChannel.name
            end

            # Create new {@link EventLoopGroup} with specified thread count. Returned group should by given to
            # {@link Bootstrap#group(EventLoopGroup)}.

            # @param threadCount amount of IO threads for the new group.
            # @return new group consistent with channel class returned by {@link #channelClass()}.
            def new_event_loop_group(thread_count)
              DriverEventLoopGroup.new(thread_count)
            end

            # Assert that current thread is not an event loop used for async IO operations. This check is needed because
            # blocking API methods like {@link Session#run(String)} are implemented on top of corresponding async API methods
            # like {@link AsyncSession#runAsync(String)} using basically {@link Future#get()} calls. Deadlocks might happen when IO
            # thread executes blocking API call and has to wait for itself to read from the network.

            # @throws IllegalStateException when current thread is an event loop IO thread.
            def assert_not_in_event_loop_thread
              if is_event_loop_thread?(java.lang.Thread.current_thread)
                raise Neo4j::Driver::Exceptions::IllegalStateException, "Blocking operation can't be executed in IO thread because it might result in a deadlock. Please do not use blocking API when chaining futures returned by async API methods."
              end
            end

            # Check if given thread is an event loop IO thread.

            # @param thread the thread to check.
            # @return {@code true} when given thread belongs to the event loop, {@code false} otherwise.
            if is_event_loop_thread?(thread)
              thread.kind_of?(DriverThread)
            end

            private

            # Same as {@link NioEventLoopGroup} but uses a different {@link ThreadFactory} that produces threads of
            # {@link DriverThread} class. Such threads can be recognized by {@link #assertNotInEventLoopThread()}.
            class DriverEventLoopGroup < io.netty.channel.nio.NioEventLoopGroup
              def initialize(n_threads)
                io.netty.channel.nio.NioEventLoopGroup.new(n_threads)
              end

              def new_default_thread_factory
                DriverThreadFactory.new
              end
            end

            #  Same as {@link DefaultThreadFactory} created by {@link NioEventLoopGroup} by default, except produces threads of
            # {@link DriverThread} class. Such threads can be recognized by {@link #assertNotInEventLoopThread()}.

            class DriverThreadFactory < io.netty.util.concurrent.DefaultThreadFactory
              def initialize
                io.netty.util.concurrent.DefaultThreadFactory.new(THREAD_NAME_PREFIX, THREAD_IS_DAEMON, THREAD_PRIORITY)
              end

              def new_thread(r, name)
                DriverThread.new(thread_group, r, name)
              end
            end

            class DriverThread < io.netty.util.concurrent.FastThreadLocalThread
              def initialize(group, target, name)
                io.netty.util.concurrent.FastThreadLocalThread.new(group, target, name)
              end
            end
          end
        end
      end
    end
  end
end
