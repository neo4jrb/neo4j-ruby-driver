module Neo4j::Driver
  module Internal
    # A basic {@link BookmarkManager} implementation.
    class Neo4jBookmarkManager
      SERIAL_VERSION_UID = 6615186840717102303
      RW_LOCK = Concurrent::ReentrantReadWriteLock.new

      def initialize(initial_bookmarks, update_listener, bookmarks_supplier)
        Internal::Validator.require_non_nil!(initial_bookmarks, "initial_bookmarks must not be nil")
        @database_to_bookmarks = initial_bookmarks
        @update_listener = update_listener
        @bookmarks_supplier = bookmarks_supplier
      end

      def update_bookmarks(database, previous_bookmarks, new_bookmarks)
        immutable_bookmarks = Util::LockUtil.execute_with_lock(RW_LOCK.with_write_lock, -> {@database_to_bookmarks.compute(database,
                                                -> (_, bookmarks) { updated_bookmarks = { }
                                                unless bookmarks.nil?
                                                  bookmarks.stream
                                                           .filter(-> (bookmark) { !previous_bookmarks.include?(bookmark) } )
                                                           .each(&:updated_bookmarks::add)}
                                                end
                                                updated_bookmarks = new_bookmarks
                                                 })})

        unless update_listener.nil?
          update_listener.accept(database, immutable_bookmarks)
        end
      end

      def bookmarks(database)
        immutable_bookmarks = Util::LockUtil.execute_with_lock(RW_LOCK.with_read_lock, -> { @database_to_bookmarks.get_or_default(database, []) })

        unless @bookmarks_supplier.nil?
          bookmarks = @bookmarks_supplier.get_bookmarks(database)
          immutable_bookmarks = bookmarks
        end

        immutable_bookmarks
      end

      def all_bookmarks
        immutable_bookmarks = Util::LockUtil.execute_with_lock(RW_LOCK.with_read_lock, -> { @database_to_bookmarks.values.stream })

        unless @bookmarks_supplier.nil?
          bookmarks = @bookmarks_supplier.get_all_bookmarks
          immutable_bookmarks = bookmarks
        end

        immutable_bookmarks
      end
    end
  end
end
