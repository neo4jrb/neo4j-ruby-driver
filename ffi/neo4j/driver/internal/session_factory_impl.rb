# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class SessionFactoryImpl
        attr_reader :connection_provider
        delegate :close, :verify_connectivity, to: :connection_provider

        def initialize(connection_provider, retry_logic, config)
          @connection_provider = connection_provider
          @retry_logic = retry_logic
          @config = config
        end

        def new_instance(mode, bookmarks)
          create_session(connection_provider, @retry_logic, mode).tap { |session| session.bookmarks = bookmarks }
        end

        private

        def create_session(connection_provider, retry_logic, mode, logging = nil)
          NetworkSession.new(connection_provider, mode, retry_logic, logging)
        end
      end
    end
  end
end
