# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalDriver
        extend AutoClosable

        auto_closable :session

        def session(*args)
          java_method(:session, [org.neo4j.driver.v1.AccessMode, java.lang.Iterable])
            .call(*Neo4j::Driver::Internal::RubySignature.session(args))
        end
      end
    end
  end
end
