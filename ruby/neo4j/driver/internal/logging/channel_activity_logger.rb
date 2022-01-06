module Neo4j::Driver
  module Internal
    module Logging
      class ChannelActivityLogger < ReformattedLogger
        def initialize(channel, logging, owner)
          super(logging.log(owner))
          @channel = channel
          @local_channel_id = channel.nil? ? nil : channel.id
        end

        def reformat(message)
          return message if @channel.nil?

          db_connection_id = db_connection_id
          server_address = server_address

          "[0x#{@local_channel_id}] [#{Util::Format.value_or_empty(server_address)}] [#{Util::Format.value_or_empty(db_connection_id)}] #{message}"
        end

        private

        def db_connection_id
          if @db_connection_id.nil?
            @db_connection_id = Async::Connection::ChannelAttributes.connection_id(@channel)
          end

          @db_connection_id
        end

        def server_address
          if @server_address.nil?
            @server_address = Async::Connection::ChannelAttributes.server_address(@channel)
          end

          @server_address
        end
      end
    end
  end
end
