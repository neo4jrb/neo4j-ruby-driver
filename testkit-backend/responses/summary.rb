module TestkitBackend
  module Responses
    class Summary < Response
      PLAN_FIELDS = %w[operator_type args identifiers].freeze
      PROFILE_FIELDS = (PLAN_FIELDS + %w[db_hits records page_cache_hits
                                        page_cache_misses page_cache_hit_ratio time]).freeze

      def data
        notifications = @object.notifications
        {
          serverInfo: to_map(@object.server, :protocol_version, :address, :agent),
          counters: to_map(@object.counters, *%w[constraints_added constraints_removed contains_system_updates? contains_updates? indexes_added
          indexes_removed labels_added labels_removed nodes_created nodes_deleted properties_set relationships_created
          relationships_deleted system_updates]),
          query: { text: @object.query.text, parameters: @object.query.parameters.transform_values(&self.class.method(:to_testkit)) },
          database: @object.database&.name,
          queryType: @object.query_type,
          notifications: (notifications_to_h(notifications) if notifications&.any?),
          gqlStatusObjects: @object.gql_status_objects.map(&method(:gql_status_to_h)),
          plan: (plan_to_h(@object.plan, PLAN_FIELDS) if @object.has_plan?),
          profile: (plan_to_h(@object.profile, PROFILE_FIELDS) if @object.has_profile?)
        }.merge!(to_map(@object, *%w[result_available_after result_consumed_after]))
      end

      private

      def to_map(o, *methods)
        methods.map { |name| [key(name), o.send(name).then { |obj| block_given? ? yield(obj) : obj }] }.to_h
      end

      def key(name)
        name.to_s.gsub('?', '').camelize(:lower).to_sym
      end

      def map_entry(n, method, *methods)
        n.send(method)&.then { |o| { key(method) => to_map(o, *methods) } } || {}
      end

      def notifications_to_h(ns)
        ns.map do |n|
          to_map(n, *%w[code title description])
            .merge(to_map(n, *%w[raw_category raw_severity_level]) { |o| o&.then(&:to_s) }.compact)
            .merge(to_map(n, *%w[category severity_level]) { |o| o.respond_to?(:name) ? o.name : (o || 'UNKNOWN') })
            .merge(map_entry(n, :position, :column, :line, :offset))
        end
      end

      # A GqlStatusObject (ResultSummary#gql_status_objects). A plain status
      # carries no position/classification/severity; a notification (the
      # GqlNotification subtype) adds them. Defaults live here — the testkit
      # shape, not driver data — so the ext only exposes what the driver has.
      def gql_status_to_h(g)
        notification = g.is_a?(Neo4j::Driver::Summary::GqlNotification)
        status = {
          gqlStatus: g.gql_status,
          statusDescription: g.status_description,
          diagnosticRecord: g.diagnostic_record.transform_values(&self.class.method(:to_testkit)),
          isNotification: notification,
          position: nil,
          classification: 'UNKNOWN',
          rawClassification: nil,
          severity: 'UNKNOWN',
          rawSeverity: nil
        }
        return status unless notification

        status.merge!(
          position: (to_map(g.position, :column, :line, :offset) if g.position),
          classification: g.classification || 'UNKNOWN',
          rawClassification: g.raw_classification,
          severity: g.severity || 'UNKNOWN',
          rawSeverity: g.raw_severity
        )
      end

      # Walks the public Plan/Profile API (operator_type, identifiers,
      # args, children — plus the ProfiledPlan extras when given the
      # PROFILE_FIELDS list). Both flavors expose the same method names,
      # so no driver-side `to_h` is needed.
      def plan_to_h(plan, fields)
        to_map(plan, *fields).merge(children: plan.children&.map { plan_to_h(it, fields) })
      end
    end
  end
end
