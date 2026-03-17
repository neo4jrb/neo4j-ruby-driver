module Testkit::Backend::Messages
  module Requests
    class ResultSingleOptional < Request
      def process
        record = fetch(result_id).first
        record = { values: record.values.map(&method(:to_testkit)) } if record
        named_entity('RecordOptional', record:, warnings: [])
      end
    end
  end
end
