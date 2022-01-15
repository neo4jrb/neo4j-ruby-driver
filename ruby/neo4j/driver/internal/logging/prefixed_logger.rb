module Neo4j::Driver
  module Internal
    module Logging
      class PrefixedLogger < ReformattedLogger
        def initialize(message_prefix = nil, delegate)
          super(delegate)

          @message_prefix = message_prefix
        end

        def reformat(message)
          return message if @message_prefix.nil?

          "#{@message_prefix} #{message}"
        end
      end
    end
  end
end
