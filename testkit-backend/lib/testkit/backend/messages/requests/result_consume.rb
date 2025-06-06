module Testkit::Backend::Messages
  module Requests
    class ResultConsume < Request
      include SummaryHelper

      def process
        summary_to_testkit(fetch(result_id).consume)
      end
    end
  end
end
