module Neo4j::Driver
  module Internal
    module Handlers
      class PingResponseHandler
        def initialize(result, channel, logger)
          @result = result
          @channel = channel
          @log = logger
        end

        def on_success(_metadata)
          @log.trace("Channel #{@channel} pinged successfully")
          @result.set_success(true)
        end

        def on_failure(error)
          @log.trace("Channel #{@channel} failed ping #{error}")
          @result.set_success(false)
        end

        def on_record(fields)
          raise java.lang.UnsupportedOperationException
        end
      end
    end
  end
end
