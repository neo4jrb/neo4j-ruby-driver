module Testkit::Backend::Messages
  module Requests
    class StartTest < Request
      SKIPPED_TESTS = {
        'neo4j.test_direct_driver.TestDirectDriver.test_custom_resolver': 'Does not call resolver for direct connections',
        'neo4j.test_direct_driver.TestDirectDriver.test_multi_db': '???',
        'neo4j.test_direct_driver.TestDirectDriver.test_supports_multi_db': '???',
        'neo4j.test_summary.TestDirectDriver.test_can_obtain_notification_info': '???',
        'neo4j.test_summary.TestDirectDriver.test_can_obtain_plan_info': '???',
        'neo4j.test_summary.TestDirectDriver.test_can_obtain_summary_after_consuming_result': '???',
        'neo4j.test_summary.TestDirectDriver.test_no_notification_info': '???',
        'neo4j.test_summary.TestDirectDriver.test_summary_counters_case_1': '???',
        'stub.iteration.test_iteration_tx_run.TestIterationTxRun.test_nested': 'completely pulls the first query before running the second',
        'stub.retry.test_retry.TestRetry.test_disconnect_on_commit': 'Keeps retrying on commit despite connection being dropped',
        'stub.retry.test_retry_clustering.TestRetryClustering.test_disconnect_on_commit': 'Keeps retrying on commit despite connection being dropped',
        'stub.session_run_parameters.test_session_run_parameters.TestSessionRunParameters.test_empty_query': 'rejects empty string',
      }.transform_keys(&:to_s)

      SKIPPED_PATTERN = {
        /stub\.routing\.test_routing_v.*\.RoutingV.*\.test_should_fail_on_routing_table_with_no_reader/ => 'needs routing table API support',
        /stub\.routing\.test_routing_v.*\.RoutingV.*\.test_should_successfully_get_routing_table$/ => 'needs routing table API support',
        /stub.versions.test_versions.TestProtocolVersions.test_should_reject_server_using_verify_connectivity_bolt_4x./ => 'Skipped because it needs investigation',
      }

      BACKEND_INCOMPLETE = [
        /test_no_routing_v.*\.NoRoutingV.*\.test_should_check_multi_db_support/,
        # /test_no_routing_v.*\.NoRoutingV.*\.test_should_error_on_commit_failure_using_tx_commit/, # GH
        # /test_no_routing_v.*\.NoRoutingV.*\.test_should_error_on_database_shutdown_using_tx_commit/, # GH
        # /test_no_routing_v.*\.NoRoutingV.*\.test_should_error_on_rollback_failure_using_session_close/, # GH
        # /test_no_routing_v.*\.NoRoutingV.*\.test_should_error_on_rollback_failure_using_tx_close/, # GH
        # /test_no_routing_v.*\.NoRoutingV.*\.test_should_error_on_rollback_failure_using_tx_rollback/, # GH
        # /test_no_routing_v.*\.NoRoutingV.*\.test_should_exclude_routing_context/, # GH
        /test_routing_v.*\.RoutingV.*\.test_should_read_successfully_on_empty_discovery_result_using_session_run/,#
        /test_routing_v.*\.RoutingV.*\.test_should_request_rt_from_all_initial_routers_until_successful/,#
        /test_routing_v.*\.RoutingV.*\.test_should_revert_to_initial_router_if_known_router_throws_protocol_errors/,#
        /test_routing_v.*\.RoutingV.*\.test_should_successfully_check_if_support_for_multi_db_is_available/,#
        /test_routing_v.*\.RoutingV.*\.test_should_use_resolver_during_rediscovery_when_existing_routers_fail/,#
        /test_routing_v.*\.RoutingV.*\.test_should_send_system_bookmark_with_route/,# flaky
        # /test_routing_v.*\.RoutingV.*\.test_should_fail_when_driver_closed_using_session_run/, # GH
        # /test_routing_v.*\.RoutingV.*\.test_should_read_successfully_from_reader_using_session_run/, # GH
        # /test_routing_v.*\.RoutingV.*\.test_should_read_successfully_from_reader_using_session_run_with_default_db_driver/, # GH
        # /test_routing_v.*\.RoutingV.*\.test_should_read_successfully_from_reader_using_tx_function/, # GH
        # /test_routing_v.*\.RoutingV.*\.test_should_read_successfully_from_reader_using_tx_run_adb/, # GH
        # /test_routing_v.*\.RoutingV.*\.test_should_read_successfully_from_reader_using_tx_run_default_db/, # GH
        # /test_routing_v.*\.RoutingV.*\.test_should_read_successfully_using_read_session_run/, # GH
        # /test_routing_v.*\.RoutingV.*\.test_should_read_successfully_using_write_session_run/, # GH
        /test_versions\.TestProtocolVersions\.test_should_reject_server_using_verify_connectivity_bolt_3x0/,
        # /test_versions\.TestProtocolVersions\.test_obtain_summary_twice/, # GH
        /test_multi_db_various_databases/,
        /test_agent_string/,
        /test_kerberos_scheme/,
        /test_protocol_version_information/,
        /TestHomeDb/,
        /TestSessionRunParameters\.test_combined/,
        /TestSessionRunParameters\.test_impersonation/,
        /TestTxBeginParameters\.test_combined/,
        /TestTxBeginParameters\.test_impersonation/,
      ]

      RUBY_DRIVER_PROBLEMS = [
'stub.authorization.test_authorization.TestAuthorizationV3.test_should_retry_on_auth_expired_on_begin_using_tx_function',
'stub.authorization.test_authorization.TestAuthorizationV3.test_should_retry_on_auth_expired_on_commit_using_tx_function',
'stub.authorization.test_authorization.TestAuthorizationV3.test_should_retry_on_auth_expired_on_pull_using_tx_function',
'stub.authorization.test_authorization.TestAuthorizationV3.test_should_retry_on_auth_expired_on_run_using_tx_function',
'stub.authorization.test_authorization.TestAuthorizationV4x1.test_should_retry_on_auth_expired_on_begin_using_tx_function',
'stub.authorization.test_authorization.TestAuthorizationV4x1.test_should_retry_on_auth_expired_on_commit_using_tx_function',
'stub.authorization.test_authorization.TestAuthorizationV4x1.test_should_retry_on_auth_expired_on_pull_using_tx_function',
'stub.authorization.test_authorization.TestAuthorizationV4x1.test_should_retry_on_auth_expired_on_run_using_tx_function',
'stub.authorization.test_authorization.TestAuthorizationV4x3.test_should_retry_on_auth_expired_on_begin_using_tx_function',
'stub.authorization.test_authorization.TestAuthorizationV4x3.test_should_retry_on_auth_expired_on_commit_using_tx_function',
'stub.authorization.test_authorization.TestAuthorizationV4x3.test_should_retry_on_auth_expired_on_pull_using_tx_function',
'stub.authorization.test_authorization.TestAuthorizationV4x3.test_should_retry_on_auth_expired_on_run_using_tx_function',
'stub.bookmarks.test_bookmarks_v3.TestBookmarksV3.test_sequence_of_writing_and_reading_tx', # flaky
'stub.bookmarks.test_bookmarks_v4.TestBookmarksV4.test_sequence_of_writing_and_reading_tx', # flaky
'stub.configuration_hints.test_connection_recv_timeout_seconds.TestDirectConnectionRecvTimeout.test_timeout_managed_tx_retry',
'stub.configuration_hints.test_connection_recv_timeout_seconds.TestRoutingConnectionRecvTimeout.test_timeout_managed_tx_retry',
'stub.configuration_hints.test_connection_recv_timeout_seconds.TestRoutingConnectionRecvTimeout.test_timeout',
'stub.configuration_hints.test_connection_recv_timeout_seconds.TestRoutingConnectionRecvTimeout.test_timeout_unmanaged_tx',
'stub.summary.test_summary.TestSummary.test_empty_notifications',
'stub.summary.test_summary.TestSummary.test_invalid_query_type',
'stub.summary.test_summary.TestSummary.test_no_times',
'stub.summary.test_summary.TestSummary.test_partial_summary_contains_system_updates',
'stub.summary.test_summary.TestSummary.test_partial_summary_contains_updates',
'stub.summary.test_summary.TestSummary.test_partial_summary_not_contains_system_updates',
'stub.summary.test_summary.TestSummary.test_partial_summary_not_contains_updates',
'stub.summary.test_summary.TestSummary.test_plan',
'stub.summary.test_summary.TestSummary.test_profile',
'stub.summary.test_summary.TestSummary.test_query',
'neo4j.test_summary.TestSummary.test_address',
'stub.iteration.test_result_peek.TestResultPeek.test_result_peek_with_0_records',
'stub.iteration.test_result_peek.TestResultPeek.test_result_peek_with_1_records',
'stub.summary.test_summary.TestSummary.test_server_info'
     ]

      def process
        if SKIPPED_TESTS.key?(testName)
          skip(SKIPPED_TESTS[testName])
        elsif reason = SKIPPED_PATTERN.find { |expr, _| testName.match?(expr) }&.last
          skip(reason)
        elsif BACKEND_INCOMPLETE.any?(&testName.method(:match?))
          skip('Backend Incomplete')
        elsif RUBY_DRIVER_PROBLEMS.include?(testName)
          skip('ruby driver problem')
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

      # def process
      #   if BACKEND_INCOMPLETE.any?(&testName.method(:match?))
      #     named_entity('RunTest')
      #   else
      #     named_entity("SkipTest", reason: 'Just testing')
      #   end
      # end

      # def process
      #   named_entity('RunTest')
      # end
    end
  end
end
