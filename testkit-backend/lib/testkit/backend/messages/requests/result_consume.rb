module Testkit::Backend::Messages
  module Requests
    class ResultConsume < Request
      def process
        named_entity('Summary',
                     {
                       serverInfo: to_map(%w[protocolVersion address agent], :server),
                       counters: to_map(%w[constraintsAdded constraintsRemoved containsSystemUpdates containsUpdates indexesAdded
          indexesRemoved labelsAdded labelsRemoved nodesCreated nodesDeleted propertiesSet relationshipsCreated
          relationshipsDeleted systemUpdates], :counters),
                       query: { text: summary.query.text, parameters: summary.query.parameters.transform_values(&method(:to_testkit)) },
                       database: summary.database.name,
                       queryType: 'rw',
                       notifications: summary.notifications.then { |ns| ns.present? ? ns.map { |n| %w[code title description severity].map { |m| [m, n.send(m)] }.to_h } : nil },
                       plan: summary.has_plan ? summary.plan.then { |p| { operator_type: p.operator_type } } : nil,
                       profile: summary.has_profile ? summary.profile.then { |p| { db_hits: p.db_hits } } : nil,
                     }.merge!(to_map(%w[resultAvailableAfter resultConsumedAfter], :itself)))
      end

      def summary
        @object ||= fetch(resultId).consume
      end

      def to_map(methods, method)
        methods.map { |name| [name.to_sym, summary.send(method).send(name.underscore)] }.to_h
      end

      # def response
      #   Responses::Summary.new(to_object)
      # end
    end
  end
end
