module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class NettyChannelTracker
          attr_reader :lock, :read, :write, :address_to_in_use_channel_count, :address_to_idle_channel_count, :log,
                      :metrics_listener, :close_listener, :all_channels

          def initialize(metrics_listener, logger, options = {},event_executor = nil, channels = nil)
            @metrics_listener = metrics_listener
            @log = logger
            @all_channels = options[:channels] ? channels : Java::IoNettyChannelGroup::DefaultChannelGroup.new("all-connections", options[:event_executor])
            @lock = java.util.concurrent.locks.ReentrantReadWriteLock.new
            @read = lock.read_lock
            @write = lock.write_lock
            @close_listener = -> (future) { channel_closed(future.channel) }
          end

          def channel_released(channel)
            do_in_write_lock do
              decrement_in_use(channel)
              increment_idle(channel)
              channel.close_future.add_listener(close_listener)
            end

            log.debug("Channel [0x#{channel.id}] acquired from the pool. Local address: #{channel.local_address}, remote address: #{channel.remote_address}")
          end

          def channel_created(channel, creating_event = nil)
            if creating_event.nil?
              raise Neo4j::Driver::Exceptions::IllegalStateException.new('Untraceable channel created.')
            else
              # when it is created, we count it as idle as it has not been acquired out of the pool
              do_in_write_lock(->() { increment_idle(channel) })

              metrics_listener.after_created(Connection::ChannelAttributes.pool_id(channel), creating_event)
              all_channels.add(channel)
              log.debug( "Channel [0x#{channel.id}] created. Local address: #{channel.local_address}, remote address: #{channel.remote_address}")
            end
          end

          def channel_creating(pool_id)
            creating_event = metrics_listener.create_listener_event
            metrics_listener.before_creating(pool_id, creating_event)
            creating_event
          end

          def channel_failed_to_create(pool_id)
            metrics_listener.after_failed_to_create(pool_id)
          end

          def channel_closed(channel)
            do_in_write_lock(-> () { decrement_idle(channel) })
            metrics_listener.after_closed(Connection::ChannelAttributes.pool_id(channel))
          end

          def in_use_channel_count(address)
            retrieve_in_read_lock(-> () { address_to_in_use_channel_count.get_or_default(address, 0) })
          end

          def idle_channel_count(address)
            retrieve_in_read_lock(-> () { address_to_idle_channel_count.get_or_default(address, 0) })
          end

          def prepare_to_close_channels
            all_channels.each do |channel|
              protocol = Messaging::BoltProtocol.for_channel(channel)
              begin
                protocol.prepare_to_close_channel(channel)
              rescue Exception => e
                # only logging it
                log.debug( "Failed to prepare to close Channel #{channel} due to error #{e.get_message}. It is safe to ignore this error as the channel will be closed despite if it is successfully prepared to close or not.")
              end
            end
          end


          private

          def increment_in_use(channel)
            increment(channel, address_to_in_use_channel_count)
          end

          def decrement_in_use(channel)
            address = Connection::ChannelAttributes.server_address(channel)

            unless address_to_in_use_channel_count.contains_key(address)
              raise Neo4j::Driver::Exceptions::IllegalStateException.new("No count exists for address '#{address}' in the 'in use' count")
            end

            count = address_to_in_use_channel_count.get(address)
            address_to_in_use_channel_count.put(address, count - 1)
          end

          def increment_idle(channel)
            increment(channel, address_to_idle_channel_count)
          end

          def decrement_idle(channel)
            address = Connection::ChannelAttributes.server_address(channel)

            unless address_to_idle_channel_count.contains_key(address)
              raise Neo4j::Driver::Exceptions::IllegalStateException.new("No count exists for address '#{address}' in the 'idle' count")
            end

            count = address_to_idle_channel_count.get(address)
            address_to_idle_channel_count.put(address, count - 1)
          end

          def increment(channel, count_map)
            address = Connection::ChannelAttributes.server_address(channel)
            count = count_map.compute_if_absent(address, -> (k) { 0 })
            count_map.put(address, count + 1)
          end

          def do_in_write_lock(work)
            begin
              write.lock
              work.run
            ensure
              write.unlock
            end
          end

          def retrieve_in_read_lock(work)
            begin
              read.lock
              work.get
            ensure
              read.unlock
            end
          end
        end
      end
    end
  end
end
