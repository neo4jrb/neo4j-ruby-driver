module Neo4j::Driver
  module Internal
    module Logging
      class ChannelErrorLogger < ChannelActivityLogger
        DEBUG_MESSAGE_FORMAT = "%s (%s)"

        def initialize(channel, logger)
          super(channel, logger, self.class)
        end

        def debug(message, error)
          super(DEBUG_MESSAGE_FORMAT % [message, error.class])
        end
      end
    end
  end
end
