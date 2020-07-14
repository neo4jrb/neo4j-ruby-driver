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

        def session(default_access_mode: Neo4j::Driver::AccessMode::WRITE, bookmarks: Bookmark.new)
          assert_open
          session_factory.new_instance(default_access_mode, [bookmarks].flatten.compact.map(&:to_set).map(&:first))
        end

        def close
          session_factory.close if @closed.make_true
          # Bolt::Connector.destroy(@connector)
        end

        private

        def assert_open
          raise Exceptions::IllegalStateException, 'This driver instance has already been closed' if @closed.true?
        end
      end
    end
  end
end
