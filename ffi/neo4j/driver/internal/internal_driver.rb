# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class InternalDriver
        extend AutoClosable
        include ErrorHandling

        attr_reader :session_factory
        delegate :verify_connectivity, to: :session_factory
        auto_closable :session

        def initialize(session_factory, logger, resolver)
          @session_factory = session_factory
          @closed = Concurrent::AtomicBoolean.new(false)
          # The below hold references to callbacks called from c,
          # this prevents garbage collection before driver is garbage collected
          @logger = logger
          @resolver = resolver
        end

        def session(*args)
          new_session(*Neo4j::Driver::Internal::RubySignature.session(args))
        end

        def close
          session_factory.close if @closed.make_true
          # Bolt::Connector.destroy(@connector)
        end

        private

        def new_session(mode, bookmarks)
          assert_open
          session_factory.new_instance(mode, bookmarks)
        end

        def assert_open
          raise Exceptions::IllegalStateException, 'This driver instance has already been closed' if @closed.true?
        end
      end
    end
  end
end
