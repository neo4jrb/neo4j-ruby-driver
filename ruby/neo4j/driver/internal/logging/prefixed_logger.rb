module Neo4j::Driver
  module Internal
    module Logging
      class PrefixedLogger < ReformattedLogger
        def initialize(message_prefix = nil, delegate)
          super(delegate)
          @message_prefix = message_prefix
        end

        private

        def format_message(severity, datetime, progname, msg)
          return super unless @message_prefix
          super(severity, datetime, progname, "#{@message_prefix} #{msg}")
        end
      end
    end
  end
end
