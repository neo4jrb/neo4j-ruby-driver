# frozen_string_literal: true

module Neo4j::Driver::Internal::Reactive
  module RxUtils
    def parse_query(query, opts)
      return if query.is_a?(Neo4j::Driver::Query)

      Neo4j::Driver::Query.new(query, parameters(opts))
    end
  end
end
