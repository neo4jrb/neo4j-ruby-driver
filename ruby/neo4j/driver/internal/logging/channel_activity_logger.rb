module Neo4j::Driver
  module Internal
    module Logging
      class ChannelActivityLogger < ReformattedLogger
        def initialize(channel, logger, owner)
          super(logger)
          @channel = channel
          @local_channel_id = channel&.id&.to_s
          @owner = owner
        end

        private

        def format_message(severity, datetime, progname, msg)
          super(severity, datetime, @owner || progname,
                @channel && "[0x#{@local_channel_id}] [#{server_address}] [#{db_connection_id}] #{msg}" || msg)
        end

        def db_connection_id
          @db_connection_id ||= Async::Connection::ChannelAttributes.connection_id(@channel)
        end

        def server_address
          @server_address ||= Async::Connection::ChannelAttributes.server_address(@channel)&.to_s
        end
      end
    end
  end
end
