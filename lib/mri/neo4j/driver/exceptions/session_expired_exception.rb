# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # A <em>SessionExpiredException</em> indicates that the session can no longer satisfy the criteria under which it
      # was acquired, e.g. a server no longer accepts write requests. A new session needs to be acquired from the driver
      # and all actions taken on the expired session must be replayed.
      # @since 1.1
      class SessionExpiredException < Neo4jException
      end
    end
  end
end
