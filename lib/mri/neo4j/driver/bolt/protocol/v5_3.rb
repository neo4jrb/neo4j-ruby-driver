# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.3. HELLO grows a required `bolt_agent` map identifying
        # the driver (product is required; the rest is informational).
        class V5_3 < V5_2
          def hello_extra(user_agent:, auth:, routing:)
            super.merge(bolt_agent: bolt_agent)
          end

          private

          def bolt_agent
            {
              product: "neo4j-ruby-driver/#{Neo4j::Driver::VERSION}",
              language: "Ruby/#{RUBY_VERSION}",
              platform: RUBY_PLATFORM
            }
          end
        end
      end
    end
  end
end
