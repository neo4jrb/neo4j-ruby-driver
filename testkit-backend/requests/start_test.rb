# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Skip patterns mirror the Java testkit-backend's StartTest
    # (sync flavor), so we automatically opt out of the same tests
    # that are unsatisfiable across the official Neo4j drivers.
    # Source: neo4j-java-driver testkit-backend StartTest.java —
    # COMMON_SKIP_PATTERN_TO_REASON + SYNC_SKIP_PATTERN_TO_REASON.
    #
    # Test names match the form testkit sends (no leading `tests.`).
    class StartTest < Data.define(:test_name)
      include Request

      SKIP_PATTERNS = {
        /\Astub\.summary\.test_summary\.TestSummaryBasicInfoDiscard\.test_times\z/ =>
          "Driver sets summary's resultAvailableAfter to -1 on discard",
        /\Astub\.routing\.test_routing_v[^.]*\.RoutingV[^.]*\.test_ipv6_read/ =>
          'Needs trying all DNS resolved addresses for hosts in the routing table',
        /\.test_no_notifications\z/ =>
          'An empty list is returned when there are no notifications',
        /\.test_no_notification_info\z/ =>
          'An empty list is returned when there are no notifications',
        /\.test_notifications_without_position\z/ =>
          'Null value is provided when position is absent',
        /\.test_multiple_notifications\z/ =>
          'Null value is provided when position is absent',
        /\.test_partial_summary_not_contains_system_updates\z/ =>
          'Contains updates because value is over zero',
        /\.test_partial_summary_not_contains_updates\z/ =>
          'Contains updates because value is over zero',
        /\.test_partial_summary_contains_system_updates\z/ =>
          'Does not contain updates because value is zero',
        /\.test_partial_summary_contains_updates\z/ =>
          'Does not contain updates because value is zero',
        /\.test_profile\z/ => 'Missing stats are reported with 0 value',
        /\.test_server_info\z/ => 'Address includes domain name',
        /\.test_supports_multi_db\z/ => 'Database is None',
        /\.TestAuthenticationSchemes[^.]+\.test_custom_scheme_empty\z/ =>
          'This test needs updating to implement expected behaviour',
        /\.TestOptimizations\.test_uses_implicit_default_arguments\z/ =>
          'Driver does not implement optimization for qid in explicit transaction',
        /\.TestOptimizations\.test_uses_implicit_default_arguments_multi_query\z/ =>
          'Driver does not implement optimization for qid in explicit transaction',
        /\.TestOptimizations\.test_uses_implicit_default_arguments_multi_query_nested\z/ =>
          'Driver does not implement optimization for qid in explicit transaction',
        /\.TestResultSingle\.test_result_single_with_2_records\z/ =>
          'This test needs updating to implement expected behaviour',
        /\.TestAuthTokenManager[^.]+\.test_notify_on_token_expired_pull_using_session_run\z/ =>
          'Background handling of pipelined PULL failure might result in manager ' \
          'notification response being sent before respective Testkit request',
        /\.TestAuthTokenManager[^.]+\.test_notify_on_token_expired_pull_using_tx_run\z/ =>
          'Background handling of pipelined PULL failure might result in manager ' \
          'notification response being sent before respective Testkit request'
      }.freeze

      def execute
        if (reason = skip_reason_for(test_name))
          Response::SkipTest.new(reason: reason)
        else
          Response::RunTest.new
        end
      end

      private

      def skip_reason_for(name)
        SKIP_PATTERNS.each { |pattern, reason| return reason if pattern.match?(name) }
        nil
      end
    end
  end
end
