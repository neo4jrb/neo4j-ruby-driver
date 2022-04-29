module Neo4j::Driver
  module Internal
    module Handlers
      class HelloResponseHandler
        include Spi::ResponseHandler
        CONNECTION_ID_METADATA_KEY = :connection_id
        CONFIGURATION_HINTS_KEY = :hints
        CONNECTION_RECEIVE_TIMEOUT_SECONDS_KEY = :'connection.recv_timeout_seconds'
        delegate :attributes, to: :@channel

        def initialize(channel, protocol_version)
          @channel = channel
          @protocol_version = protocol_version
        end

        def on_success(metadata)
          begin
            attributes[:server_agent] = Util::MetadataExtractor.extract_server(metadata)
            # From Server V4 extracting server from metadata in the success message is unreliable
            # so we fix the Server version against the Bolt Protocol version for Server V4 and above.
            attributes[:server_version] =
              if Messaging::V3::BoltProtocolV3::VERSION == @protocol_version
                Util::MetadataExtractor.extract_neo4j_server_version(metadata)
              else
                Util::ServerVersion.from_bolt_protocol_version(@protocol_version)
              end

            attributes[:connection_id] = extract_connection_id(metadata)
            process_configuration_hints(metadata)
          rescue => error
            on_failure(error)
            raise error
          end
        end

        def on_failure(error)
          @channel.close
          raise error ### Not sure about that
        end

        def on_record(_fields)
          raise NotImplementedError
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
          metadata[CONFIGURATION_HINTS_KEY]&.dig(CONNECTION_RECEIVE_TIMEOUT_SECONDS_KEY)&.tap do |value|
            attributes[:connection_read_timeout] = value
          end
        end
      end
    end
  end
end
