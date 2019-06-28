# frozen_string_literal: true

# Workaround for missing zeitwerk support in jruby-9.2.7.0
if RUBY_PLATFORM.match?(/java/)
  module Bolt
  end
  module Neo4j
    module Driver
      module Types
      end
    end
  end
end
# End workaround

require 'ffi'
require 'loader'
Loader.load
