module Neo4j::Driver
  module Internal
    module Logging
      class ChannelErrorLogger < ChannelActivityLogger
        DEBUG_MESSAGE_FORMAT = "%s (%s)"

        def initialize(channel, logging)
          super(channel, logging, self.class)
        end

        def trace_or_debug(message, error)
          if trace_enabled?
            trace(message, error)
          else
            debug(DEBUG_MESSAGE_FORMAT % [message, error.self.class])
          end
        end
      end
    end
  end
end
