# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Async
        class AccessModeConnection
          attr_reader :connection, :mode
          delegate :open?, :protocol, :release, :reset, :write_and_flush, to: :connection

          def initialize(connection, mode)
            @connection = connection
            @mode = mode
          end
        end
      end
    end
  end
end
