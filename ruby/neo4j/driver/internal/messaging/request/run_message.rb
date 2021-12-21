module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class RunMessage
          SIGNATURE = 0x10

          attr_reader :query, :parameters

          def initialize(query, parameters = nil)
            @query = query
            @parameters = parameters
          end

          def to_s
            "RUN \"#{query}\" #{parameters}"
          end

          def equals(object)
            return true if self == object

            return false if object.nil? || self.class != object.class

            !(!parameters.nil? ? !parameters.equals(object.parameters) : !object.parameters.nil?) &&
            !(!query.nil? ? !query.equals(object.query) : !object.query.nil?)
          end

          def hash_code
            result = !query.nil? ? query.hash_code : 0
            result = 31 * result + (!parameters.nil? ? parameters.hash_code : 0)
            result
          end
        end
      end
    end
  end
end
