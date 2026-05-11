# frozen_string_literal: true

module Neo4j
  module Driver
    module Summary
      # The query (text + parameters) the summary describes. Mirrors
      # org.neo4j.driver.Query but lives under Summary:: for the same
      # reason as the rest — the user reaches it via Summary#query.
      class Query
        attr_reader :text, :parameters

        def initialize(text, parameters = {})
          @text = text
          @parameters = parameters
        end
      end
    end
  end
end
