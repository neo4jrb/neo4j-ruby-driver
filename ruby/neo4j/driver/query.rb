module Neo4j
  module Driver
    # The components of a Cypher query, containing the query text and parameter map.

    # @see Session
    # @see Transaction
    # @see Result
    # @see Result#consume()
    # @see ResultSummary
    # @since 1.0
    class Query < Struct.new(:text, :parameters)
      # @param newText the new query text
      # @return a new Query object with updated text
      def with_text(new_text)
        new(new_text, parameters)
      end

      def with_parameters(new_parameters)
        new(text, new_parameters)
      end

      # Create a new query with new parameters derived by updating this'
      # query's parameters using the given updates.

      # Every update key that points to a null value will be removed from
      # the new query's parameters. All other entries will just replace
      # any existing parameter in the new query.

      # @param updates describing how to update the parameters
      # @return a new query with updated parameters
      def with_updated_parameters(updates)
        return self if updates.nil? || updates.empty?

        new_parameters = parameters

        updates.each do |key, value|
          if value.nil?
            new_parameters.delete(key)
          else
            new_parameters[key] = value
          end
        end

        with_parameters(new_parameters)
      end
    end
  end
end
