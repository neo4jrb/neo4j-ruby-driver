module Neo4j::Driver
  module Internal
    module Async
      module ConnectionContext
        PENDING_DATABASE_NAME_EXCEPTION_SUPPLIER =
          ->() { Exceptions::IllegalStateException.new('Pending database name encountered') }
      end
    end
  end
end
