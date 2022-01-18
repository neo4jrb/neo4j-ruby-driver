# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # A signal that the contract for client-server communication has broken down.
      # The user should contact support and cannot resolve this his or herself.
      class ProtocolException < Neo4jException
        CODE = "Protocol violation: "

        def initialize(message, e)
          super("#{CODE}message", e)
        end
      end
    end
  end
end
