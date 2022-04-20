module Neo4j::Driver
  module Internal
    module Handlers
      class InitResponseHandler
        include Spi::ResponseHandler

        def initialize(connection_initialized_promise)
          @connection_initialized_promise = connection_initialized_promise
          @channel = connection_initialized_promise
        end

        def on_success(_metadata)
          begin
            server_version = Util::MetadataExtractor.extract_neo4j_server_version(metadata)
            Async::Connection::ChannelAttributes.set_server_version(@channel, server_version)

            @connection_initialized_promise.set_success
          rescue StandardError => error
            @connection_initialized_promise.set_failure(error)
            raise error
          end
        end

        def on_failure(error)
          @channel.close.add_listener(-> (_future) { @connection_initialized_promise.set_failure(error) })
        end

        def on_record(fields)
          raise java.lang.UnsupportedOperationException
        end
      end
    end
  end
end
