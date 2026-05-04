# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # A feature is not supported in a given setup.
      class UnsupportedFeatureException < ClientException
      end
    end
  end
end
