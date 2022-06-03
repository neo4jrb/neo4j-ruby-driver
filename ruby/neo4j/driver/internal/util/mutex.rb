module Neo4j::Driver::Internal
  module Util
    class Mutex < Mutex
      def synchronize
        owned? ? yield : super
      end
    end
  end
end
