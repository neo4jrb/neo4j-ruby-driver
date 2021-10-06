module Testkit::Backend::Messages
  module Responses
    class Summary < Response
      def data
        { serverInfo: to_map(%w[protocolVersion address agent], :server),
          counters: to_map(%w[constraintsAdded constraintsRemoved containsSystemUpdates containsUpdates indexesAdded
          indexesRemoved labelsAdded labelsRemoved nodesCreated nodesDeleted propertiesSet relationshipsCreated
          relationshipsDeleted systemUpdates], :counters),
          query: { text: @object.query.text, parameters: @object.query.parameters }
        }.merge!(
          to_map(%w[database notifications plan profile queryType resultAvailableAfter resultConsumedAfter], :itself))
      end

      private

      def to_map(methods, method)
        methods.map { |name| [name.to_sym, @object.send(method).send(name.underscore)] }.to_h
      end
    end
  end
end
