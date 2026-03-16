module Testkit::Backend::Messages
  module Requests
    class CypherTypeField < AbstractResultNext
      def process
        reference('BookmarkManager')
      end

      def to_object
        delete(id).tap(&:close)
      end
    end
  end
end
