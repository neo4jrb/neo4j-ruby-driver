# frozen_string_literal: true

# Workaround for missing zeitwerk support in jruby-9.2.8.0
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
        module Retry
        end
        module Summary
        end
        module Util
        end
        module Value
        end
      end
      module Net
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
require 'active_support/core_ext/array/grouping'
require 'concurrent/atomic/atomic_boolean'
require 'concurrent/atomic/atomic_reference'
require 'ffi'
require 'fiddle'
require 'loader'
require 'recursive-open-struct'

module Neo4j
  module Driver
  end
end

Loader.load

Neo4j::Driver::Record = Neo4j::Driver::Internal::InternalRecord
Neo4j::Driver::StatementResult = Neo4j::Driver::Internal::InternalStatementResult
Neo4j::Driver::Transaction = Neo4j::Driver::Internal::ExplicitTransaction
