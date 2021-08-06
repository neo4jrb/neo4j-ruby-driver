module Testkit::Backend::Messages
  module Requests
    class StartTest < Request
      def process
        named_entity('RunTest')
      end
    end
  end
end
