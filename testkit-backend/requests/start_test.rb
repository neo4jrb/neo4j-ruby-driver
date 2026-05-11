module TestkitBackend
  module Requests
    # Skip patterns mirror the Java testkit-backend's StartTest
    # (COMMON + SYNC patterns), so we automatically opt out of the
    # same tests that are unsatisfiable across the official Neo4j
    # drivers. Source: neo4j-java-driver testkit-backend StartTest.java.
    class StartTest < Request
      # Single-test exact-match skips.
      SKIP_EXACT = {
        'neo4j.test_direct_driver.TestDirectDriver.test_custom_resolver' =>
          'Does not call resolver for direct connections (hardcoded skip in Java)',
        'stub.session_run_parameters.test_session_run_parameters.TestSessionRunParameters.test_empty_query' =>
          'Rejects empty string (hardcoded skip in Java)'
      }.freeze

      # Regex-pattern skips. Ordered from most-specific to most-general
      # so a path-pinned reason wins over a name-suffix reason.
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
        /\.TestOptimizations\.test_uses_implicit_default_arguments(?:_multi_query(?:_nested)?)?\z/ =>
          'Driver does not implement optimization for qid in explicit transaction',
        /\.TestResultSingle\.test_result_single_with_2_records\z/ =>
          'This test needs updating to implement expected behaviour',
        /\.TestConnectionAcquisitionTimeoutMs\.test_should_encompass_the_handshake_time/ =>
          'Driver handles connection acquisition timeout differently',
        /\.TestConnectionAcquisitionTimeoutMs\.test_router_handshake_has_own_timeout_too_slow\z/ =>
          'Driver handles connection acquisition timeout differently',
        /\.TestConnectionAcquisitionTimeoutMs\.test_should_fail_when_acquisition_timeout_is_reached_first/ =>
          'Driver handles connection acquisition timeout differently',
        /\.TestConnectionAcquisitionTimeoutMs\.test_should_encompass_the_version_handshake_(?:in_time|time_out)\z/ =>
          'Driver handles connection acquisition timeout differently',
        /\.TestAuthenticationSchemes[^.]+\.test_(?:basic|bearer|custom|kerberos)_scheme\z/ =>
          'Tests for driver with API_AUTH_PIPELINING are (currently) missing when logon is supported',
        /\.TestAuthTokenManager[^.]+\.test_notify_on_token_expired_pull_using_(?:session|tx)_run\z/ =>
          'Background handling of pipelined PULL failure might result in manager ' \
          'notification response being sent before respective Testkit request'
      }.freeze

      def process
        reason = SKIP_EXACT[test_name] ||
                 SKIP_PATTERNS.find { |pattern, _| pattern.match?(test_name) }&.last
        reason ? skip(reason) : run
      end

      def run(_ = nil)
        named_entity('RunTest')
      end

      def skip(reason = 'Skipping passing')
        named_entity('SkipTest', reason: reason)
      end
    end
  end
end
