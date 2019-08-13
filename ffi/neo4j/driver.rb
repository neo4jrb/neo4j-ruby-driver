# frozen_string_literal: true

# Workaround for missing zeitwerk support in jruby-9.2.7.0
if RUBY_PLATFORM.match?(/java/)
  module Bolt
  end
  module Neo4j
    module Driver
      module Internal
        module Async
        end
        module Handlers
        end
        module Messaging
          module V1
          end
          module V2
          end
          module V3
          end
        end
        module Summary
        end
        module Util
        end
        module Value
        end
      end
      module Summary
      end
      module Types
      end
    end
  end
end
# End workaround

require 'active_support/concern'
require 'concurrent/atomic/atomic_boolean'
require 'concurrent/atomic/atomic_reference'
require 'ffi'
require 'loader'
require 'recursive-open-struct'
Loader.load
