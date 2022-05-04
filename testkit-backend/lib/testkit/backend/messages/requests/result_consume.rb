module Testkit::Backend::Messages
  module Requests
    class ResultConsume < Request
      def process
        named_entity('Summary',
                     **{
                       serverInfo: to_map(summary.server, :protocol_version, :address, :agent),
                       # serverInfo: to_map(summary.server, :protocol_version, :agent),
                       counters: to_map(summary.counters, *%w[constraints_added constraints_removed contains_system_updates contains_updates indexes_added
          indexes_removed labels_added labels_removed nodes_created nodes_deleted properties_set relationships_created
          relationships_deleted system_updates]),
                       query: { text: summary.query.text, parameters: summary.query.parameters.transform_values(&method(:to_testkit)) },
                       database: summary.database.name,
                       queryType: summary.query_type,
                       notifications: summary.notifications.then { |ns| ns.present? ? notifications(ns) : nil },
                       plan: summary.has_plan ? summary.plan.then { |p| { operator_type: p.operator_type } } : nil,
                       profile: summary.has_profile ? summary.profile.then { |p| { db_hits: p.db_hits } } : nil,
                     }.merge!(to_map(summary, *%w[result_available_after result_consumed_after])))
      end

      private

      def summary
        @object ||= fetch(resultId).consume
      end

      def to_map(o, *methods)
        methods.map { |name| [key(name), o.send(name)] }.to_h
      end

      def key(name)
        name.to_s.camelize(:lower).to_sym
      end

      def map_entry(n, method, *methods)
        n.send(method)&.then { |o| { key(method) => to_map(o, *methods) } } || {}
      end

      def notifications(ns)
        ns.map { |n| to_map(n, *%w[code title description severity]).merge(map_entry(n, :position, :column, :line, :offset)) }
      end
    end
  end
end
