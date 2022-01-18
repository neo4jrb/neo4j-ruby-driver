# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # Thrown if the remote server cannot be verified as Neo4j.
      class UntrustedServerException < RuntimeError
        def initialize(message)
          super(message)
        end
      end
    end
  end
end
