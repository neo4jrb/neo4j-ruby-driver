module Neo4j::Driver
  module Internal
    class InternalEagerResult
      attr_reader :records, :summary

      def initialize(records, summary)
        @records = records
        @summary = summary
      end
    end
  end
end
