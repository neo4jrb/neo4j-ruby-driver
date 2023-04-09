module Testkit::Backend::Messages
  module Requests
    class StartTest < Request
      SKIPPED_TESTS = {
        'neo4j.test_direct_driver.TestDirectDriver.test_custom_resolver': 'Does not call resolver for direct connections',
        'stub.iteration.test_iteration_tx_run.TestIterationTxRun.test_nested': 'completely pulls the first query before running the second',
        'stub.optimizations.test_optimizations.TestOptimizations.test_uses_implicit_default_arguments': 'Driver does not implement optimization for qid in explicit transaction',
        'stub.optimizations.test_optimizations.TestOptimizations.test_uses_implicit_default_arguments_multi_query': 'Driver does not implement optimization for qid in explicit transaction',
        'stub.optimizations.test_optimizations.TestOptimizations.test_uses_implicit_default_arguments_multi_query_nested': 'Driver does not implement optimization for qid in explicit transaction',
        'stub.retry.test_retry.TestRetry.test_disconnect_on_commit': 'Keeps retrying on commit despite connection being dropped',
        'stub.retry.test_retry_clustering.TestRetryClustering.test_disconnect_on_commit': 'Keeps retrying on commit despite connection being dropped',
        'stub.session_run_parameters.test_session_run_parameters.TestSessionRunParameters.test_empty_query': 'rejects empty string',
        'stub.summary.test_summary.TestSummary.test_server_info': 'Address includes domain name',
        'stub.versions.test_versions.TestProtocolVersions.test_obtain_summary_twice': 'Address includes domain name',
        'stub.versions.test_versions.TestProtocolVersions.test_server_address_in_summary': 'Address includes domain name',
        'tls.test_self_signed_scheme.TestTrustAllCertsConfig.test_trusted_ca_wrong_hostname': 'This test expects hostname verification to be turned off when all certificates are trusted',
        'tls.test_self_signed_scheme.TestTrustAllCertsConfig.test_untrusted_ca_wrong_hostname': 'This test expects hostname verification to be turned off when all certificates are trusted',
      }.transform_keys(&:to_s)

      SKIPPED_PATTERN = {
        /stub\.bookmarks\.test_bookmarks_v.\.TestBookmarksV.\.test_sequence_of_writing_and_reading_tx/ => 'random timeouts',
        /stub\.routing\.test_routing_v4x1\.RoutingV4x1\.test_should_pass_bookmark_from_tx_to_tx_using_tx_run$/ => 'random timeouts',
        /stub\.routing\.test_routing_v4x4\.RoutingV4x4\.test_should_send_system_bookmark_with_route$/ => 'random timeouts',
        /stub\.routing\.test_routing_v.*\.RoutingV.*\.test_should_fail_on_routing_table_with_no_reader/ => 'needs routing table API support',
        /stub\.routing\.test_routing_v.*\.RoutingV.*\.test_should_successfully_get_routing_table$/ => 'needs routing table API support',
        /stub.versions.test_versions.TestProtocolVersions.test_should_reject_server_using_verify_connectivity_bolt_4x./ => 'Skipped because it needs investigation',
        /test_should_fail_on_routing_table_with_no_reader/ => '???',
      }

      BACKEND_INCOMPLETE = [
        /test_routing_v.*\.RoutingV.*\.test_should_read_successfully_on_empty_discovery_result_using_session_run/, #
        /test_routing_v.*\.RoutingV.*\.test_should_revert_to_initial_router_if_known_router_throws_protocol_errors/, #
        /test_versions\.TestProtocolVersions\.test_should_reject_server_using_verify_connectivity_bolt_3x0/,
        /stub\.authorization\.test_authorization\.TestAuthenticationSchemes\.test_custom_scheme_empty/,
        /stub\.iteration\.test_result_list\.TestResultList\.test_.*_result_list_pulls_all_records_at_once.*/,
        /stub.routing.test_no_routing_v4x1.NoRoutingV4x1.test_should_pull_custom_size_and_then_all_using_session_configuration/,
      ]

      RUBY_DRIVER_PROBLEMS = [
        'neo4j.test_summary.TestSummary.test_address',
        'stub.configuration_hints.test_connection_recv_timeout_seconds.TestRoutingConnectionRecvTimeout.test_timeout_managed_tx_retry',
        'stub.configuration_hints.test_connection_recv_timeout_seconds.TestRoutingConnectionRecvTimeout.test_timeout',
        'stub.configuration_hints.test_connection_recv_timeout_seconds.TestRoutingConnectionRecvTimeout.test_timeout_unmanaged_tx',
        'stub.iteration.test_result_peek.TestResultPeek.test_result_peek_with_0_records',
        'stub.iteration.test_result_peek.TestResultPeek.test_result_peek_with_1_records',
        'stub.summary.test_summary.TestSummary.test_empty_notifications',
        'stub.summary.test_summary.TestSummary.test_invalid_query_type',
        'stub.summary.test_summary.TestSummary.test_no_times',
        'stub.summary.test_summary.TestSummary.test_partial_summary_contains_system_updates',
        'stub.summary.test_summary.TestSummary.test_partial_summary_contains_updates',
        'stub.summary.test_summary.TestSummary.test_partial_summary_not_contains_system_updates',
        'stub.summary.test_summary.TestSummary.test_partial_summary_not_contains_updates',
        'stub.summary.test_summary.TestSummary.test_plan',
        'stub.summary.test_summary.TestSummary.test_profile',
      ]

      DOMAIN_RESOLVER_ON_JAVA = [
        /test_routing_v.*\.RoutingV.*\.test_should_request_rt_from_all_initial_routers_until_successful/,
        /test_routing_v.*\.RoutingV.*\.test_should_successfully_acquire_rt_when_router_ip_changes/,
      ]

      COMMON_SKIP_PATTERN_TO_REASON = {}
      def COMMON_SKIP_PATTERN_TO_REASON.put(key, value)
        store(Regexp.new(key), value)
      end

      def self.var(_); end

      #### Copied from java without any changes
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.test_no_notifications$", "An empty list is returned when there are no notifications");
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.test_no_notification_info$", "An empty list is returned when there are no notifications");
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.test_notifications_without_position$", "Null value is provided when position is absent");
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.test_multiple_notifications$", "Null value is provided when position is absent");
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.test_partial_summary_not_contains_system_updates$",
        "Contains updates because value is over zero");
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.test_partial_summary_not_contains_updates$", "Contains updates because value is over zero");
      COMMON_SKIP_PATTERN_TO_REASON.put("^.*\\.test_profile$", "Missing stats are reported with 0 value");
      COMMON_SKIP_PATTERN_TO_REASON.put("^.*\\.test_server_info$", "Address includes domain name");
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.test_partial_summary_contains_system_updates$",
        "Does not contain updates because value is zero");
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.test_partial_summary_contains_updates$", "Does not contain updates because value is zero");
      COMMON_SKIP_PATTERN_TO_REASON.put("^.*\\.test_supports_multi_db$", "Database is None");
      var skipMessage = "Driver handles connection acquisition timeout differently";
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.TestConnectionAcquisitionTimeoutMs\\.test_should_encompass_the_handshake_time.*$", skipMessage);
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.TestConnectionAcquisitionTimeoutMs\\.test_router_handshake_has_own_timeout_too_slow$",
        skipMessage);
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.TestConnectionAcquisitionTimeoutMs\\.test_should_fail_when_acquisition_timeout_is_reached_first.*$",
        skipMessage);
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.TestConnectionAcquisitionTimeoutMs\\.test_should_encompass_the_version_handshake_(in_time|time_out)$",
        skipMessage);
      skipMessage = "This test needs updating to implement expected behaviour";
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.TestAuthenticationSchemes[^.]+\\.test_custom_scheme_empty$", skipMessage);
      skipMessage = "Driver does not implement optimization for qid in explicit transaction";
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.TestOptimizations\\.test_uses_implicit_default_arguments$", skipMessage);
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.TestOptimizations\\.test_uses_implicit_default_arguments_multi_query$", skipMessage);
      COMMON_SKIP_PATTERN_TO_REASON.put(
        "^.*\\.TestOptimizations\\.test_uses_implicit_default_arguments_multi_query_nested$", skipMessage);
      skipMessage =
        "Tests for driver with types.Feature.OPT_IMPLICIT_DEFAULT_ARGUMENTS but without types.Feature.OPT_AUTH_PIPELINING are (currently) missing when logon is supported";
      COMMON_SKIP_PATTERN_TO_REASON.put("^.*\\.TestAuthenticationSchemes[^.]+\\.test_basic_scheme$", skipMessage);
      COMMON_SKIP_PATTERN_TO_REASON.put("^.*\\.TestAuthenticationSchemes[^.]+\\.test_bearer_scheme$", skipMessage);
      COMMON_SKIP_PATTERN_TO_REASON.put("^.*\\.TestAuthenticationSchemes[^.]+\\.test_custom_scheme$", skipMessage);
      COMMON_SKIP_PATTERN_TO_REASON.put("^.*\\.TestAuthenticationSchemes[^.]+\\.test_kerberos_scheme$", skipMessage);
      # End copy from java

      def process
        if false
        # elsif SKIPPED_TESTS.key?(test_name)
        #   skip(SKIPPED_TESTS[test_name])
        # elsif reason = SKIPPED_PATTERN.find { |expr, _| test_name.match?(expr) }&.last
        #   skip(reason)
        # elsif BACKEND_INCOMPLETE.any?(&test_name.method(:match?))
        #   skip('Backend Incomplete')
        # elsif RUBY_DRIVER_PROBLEMS.include?(test_name)
        #   skip('ruby driver problem')
        # elsif RUBY_PLATFORM == 'java' && DOMAIN_RESOLVER_ON_JAVA.any?(&test_name.method(:match?))
        #   skip('Domain Resolver hard to implement on jruby due to default visibility and protected not implemented correctly in jruby')
        elsif reason = COMMON_SKIP_PATTERN_TO_REASON.find { |expr, _| test_name.match?(expr) }&.last
          skip(reason)
        else
          run
        end
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
