module Testkit::Backend::Messages
  module Requests
    class ResultList < Request
      def process
        result = fetch(result_id)
        named_entity('RecordList', records: result.map do |record|
          { values: record.values.map do |value|
            to_testkit(value)
          end }
        end
        )
      end
    end
  end
end
