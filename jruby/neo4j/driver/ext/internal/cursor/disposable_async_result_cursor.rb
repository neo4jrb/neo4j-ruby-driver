# frozen_string_literal: true

module Neo4j::Driver::Ext
  module Internal
    module Cursor
      module DisposableAsyncResultCursor
        include AsyncConverter

        def next_async
          to_future(super)
        end
      end
    end
  end
end
