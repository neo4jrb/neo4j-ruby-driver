module TestkitBackend
  module Requests
    class ResultList < Request
      def process = named_entity('RecordList', records: fetch(result_id).to_a.map { Responses::Record.new(it).data })
    end
  end
end
