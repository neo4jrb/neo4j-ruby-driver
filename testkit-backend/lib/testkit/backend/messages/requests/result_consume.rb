module Testkit::Backend::Messages
  module Requests
    class ResultConsume < Request
      def process
        named_entity('Summary',
                     **{
                       serverInfo: to_map(summary.server, :protocol_version, :address, :agent),
                       counters: to_map(summary.counters, *%w[constraints_added constraints_removed contains_system_updates? contains_updates? indexes_added
          indexes_removed labels_added labels_removed nodes_created nodes_deleted properties_set relationships_created
          relationships_deleted system_updates]),
                       query: { text: summary.query.text, parameters: summary.query.parameters.transform_values(&method(:to_testkit)) },
                       database: summary.database.name,
                       queryType: summary.query_type,
                       notifications: summary.notifications&.then(&method(:notifications)),
                       plan: (plan_to_h(summary.plan) if summary.has_plan?),
                       profile: summary.has_profile? ? summary.profile.then { |p| { db_hits: p.db_hits } } : nil,
                     }.merge!(to_map(summary, *%w[result_available_after result_consumed_after])))
      end

      private

      def summary
        @object ||= fetch(result_id).consume
      end

      def to_map(o, *methods)
        methods.map { |name| [key(name), o.send(name).then { |obj| block_given? ? yield(obj) : obj }] }.to_h
      end

      def key(name)
        name.to_s.gsub('?', '').camelize(:lower).to_sym
      end

      def map_entry(n, method, *methods)
        n.send(method)&.then { |o| { key(method) => to_map(o, *methods) } } || {}
      end

      def notifications(ns)
        ns.map do |n|
          to_map(n, *%w[code title description raw_category severity raw_severity_level])
            .merge(to_map(n, *%w[category severity_level]) { |o| o&.type || 'UNKNOWN' })
            .merge(map_entry(n, :position, :column, :line, :offset))
        end
      end

      def plan_to_h(plan)
        plan.to_h.transform_keys(&method(:key)).tap {|hash| hash[:children]&.map!(&method(:plan_to_h))}
      end
    end
  end
end
