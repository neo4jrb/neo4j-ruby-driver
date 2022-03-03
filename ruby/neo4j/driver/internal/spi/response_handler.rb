module Neo4j::Driver
  module Internal
    module Spi
      module ResponseHandler
        # Tells whether this response handler is able to manage auto-read of the underlying connection using {@link Connection#enableAutoRead()} and
        # {@link Connection#disableAutoRead()}.
        # <p>
        # Implementations can use auto-read management to apply network-level backpressure when receiving a stream of records.
        # There should only be a single such handler active for a connection at one point in time. Otherwise, handlers can interfere and turn on/off auto-read
        # racing with each other. {@link InboundMessageDispatcher} is responsible for tracking these handlers and disabling auto-read management to maintain just
        # a single auto-read managing handler per connection.
        def can_manage_auto_read
          false
        end
        
        # If this response handler is able to manage auto-read of the underlying connection, then this method signals it to
        # stop changing auto-read setting for the connection.
        def disable_auto_read_management
        end
      end
    end
  end
end
