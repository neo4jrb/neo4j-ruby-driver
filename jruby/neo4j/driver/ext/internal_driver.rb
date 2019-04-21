# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalDriver
        extend Neo4j::Driver::AutoClosable

        auto_closable :session

        # def session(mode = AccessMode::WRITE, *bookmarks)
        #   java_method(:session, [org.neo4j.driver.v1.AccessMode, java.lang.Iterable]).call(mode, bookmarks)
        # end
      end
    end
  end
end
