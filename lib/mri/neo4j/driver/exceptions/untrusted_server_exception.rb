# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # Thrown if the remote server cannot be verified as Neo4j.
      class UntrustedServerException < RuntimeError
      end
    end
  end
end
