module Testkit::Backend::Messages
  module Requests
    class ResultSingleOptional < Request
      def process
        result = fetch(result_id)
        record = begin
          { values: result.single.values.map(&method(:to_testkit)) }
        rescue Neo4j::Driver::Exceptions::NoSuchRecordException
          nil
        end
        named_entity('RecordOptional', record:, warnings: [])
      end
    end
  end
end
