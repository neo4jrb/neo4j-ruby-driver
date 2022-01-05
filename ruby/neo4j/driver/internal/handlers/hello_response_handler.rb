module Neo4j::Driver
  module Internal
    module Handlers
      class HelloResponseHandler
        CONNECTION_ID_METADATA_KEY = :connection_id
        CONFIGURATION_HINTS_KEY = :hints
        CONNECTION_RECEIVE_TIMEOUT_SECONDS_KEY = :'connection.recv_timeout_seconds'

        def initialize(connection_initialized_promise, protocol_version)
          @connection_initialized_promise = connection_initialized_promise
          @channel = connection_initialized_promise.channel
          @protocol_version = protocol_version
        end

        def on_success(metadata)
          begin
            server_value = Util::MetadataExtractor.extract_server(metadata)
            Async::Connection::ChannelAttributes.set_server_agent(@channel, server_value)

            # From Server V4 extracting server from metadata in the success message is unreliable
            # so we fix the Server version against the Bolt Protocol version for Server V4 and above.
            if Messaging::V3::BoltProtocolV3::VERSION.eql?(@protocol_version)
              Async::Connection::ChannelAttributes.set_server_version(@channel, Util::MetadataExtractor.extract_neo4j_server_version(metadata))
            else
              Async::Connection::ChannelAttributes.set_server_version(@channel, Util::ServerVersion.from_bolt_protocol_version(@protocol_version))
            end

            connection_id = extract_connection_id(metadata)
            Async::Connection::ChannelAttributes.set_connection_id(@channel, connection_id)
            process_configuration_hints(metadata)
            @connection_initialized_promise.set_success
          rescue StandardError => error
            on_failure(error)
            raise error
          end
        end

        def on_failure(error)
          @channel.close.add_listener(-> (_future) { @connection_initialized_promise.set_failure(error) })
        end

        def on_record(fields)
          raise java.lang.UnsupportedOperationException
        end

        private

        def extract_connection_id(metadata)
          value = metadata[CONNECTION_ID_METADATA_KEY]

          if value.nil?
            raise Exceptions::IllegalStateException, "Unable to extract #{CONNECTION_ID_METADATA_KEY} from a response to HELLO message. Received metadata: #{metadata}"
          end

          value
        end

        def process_configuration_hints(metadata)
          configuration_hints = metadata[CONFIGURATION_HINTS_KEY]

          if configuration_hints.nil?
            get_from_supplier_or_empty_on_exception do
              configuration_hints[CONNECTION_RECEIVE_TIMEOUT_SECONDS_KEY]
            end.if_present do |timeout|
                  Async::connection::ChannelAttributes.set_connection_read_timeout(@channel, timeout)
                end
          end
        end

        def get_from_supplier_or_empty_on_exception(supplier)
          begin
            java.util.Optional.of(supplier)
          rescue StandardError => e
            java.util.Optional.empty
          end
        end
      end
    end
  end
end
