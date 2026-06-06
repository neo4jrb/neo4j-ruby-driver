module TestkitBackend
  module Requests
    # Skip patterns mirror the Java testkit-backend's StartTest
    # COMMON_SKIP_PATTERN_TO_REASON + SYNC_SKIP_PATTERN_TO_REASON,
    # so we automatically opt out of the same tests the Java driver
    # opts out of. Source: neo4j-java-driver testkit-backend
    # StartTest.java. Re-check when bumping testkit pinning in CI.
    class StartTest < Request
      SKIP_PATTERNS = {
        # --- COMMON ----------------------------------------------------------
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
        /\.test_profile\z/ => 'Missing stats are reported with 0 value',
        /\.test_server_info\z/ => 'Address includes domain name',
        /\.test_partial_summary_contains_system_updates\z/ =>
          'Does not contain updates because value is zero',
        /\.test_partial_summary_contains_updates\z/ =>
          'Does not contain updates because value is zero',
        /\.test_supports_multi_db\z/ => 'Database is None',
        # The driver validates query text client-side and rejects empty
        # strings (matching Java/JS, which testkit also skips here); this
        # test expects the empty query to be sent to the server.
        /\.test_empty_query\z/ =>
          'Driver rejects empty query strings client-side (like Java/JS)',
        /\.TestAuthenticationSchemes[^.]+\.test_custom_scheme_empty\z/ =>
          'This test needs updating to implement expected behaviour',
        /\.TestOptimizations\.test_uses_implicit_default_arguments(?:_multi_query(?:_nested)?)?\z/ =>
          'Driver does not implement optimization for qid in explicit transaction',
        /\.TestResultSingle\.test_result_single_with_2_records\z/ =>
          'This test needs updating to implement expected behaviour',
        /\Astub\.routing\.test_routing_v[^.]*\.RoutingV[^.]*\.test_ipv6_read/ =>
          'Needs trying all DNS resolved addresses for hosts in the routing table',
        /\Astub\.summary\.test_summary\.TestSummaryBasicInfoDiscard\.test_times\z/ =>
          "Driver sets summary's resultAvailableAfter to -1 on discard",

        # --- SYNC ------------------------------------------------------------
        /\.TestAuthTokenManager[^.]+\.test_notify_on_token_expired_pull_using_(?:session|tx)_run\z/ =>
          'Background handling of pipelined PULL failure might result in manager ' \
          'notification response being sent before respective Testkit request',

        # --- Ruby-specific ---------------------------------------------------
        # testkit itself hard-skips this test for java / dotnet /
        # javascript with the reason below (see tests/stub/retry/
        # test_retry_clustering.py and test_retry.py — `if
        # get_driver_name() in ["java", "dotnet", "javascript"]`). Ruby
        # isn't on that list so we get the test by default, but our
        # behaviour matches Java's here. Skip with the same reason
        # rather than play timing roulette with the disconnect-during-
        # commit detection.
        /\Astub\.retry\.test_retry(?:_clustering)?\.TestRetry(?:Clustering)?\.test_disconnect_on_commit\z/ =>
          'Keeps retrying on commit despite connection being dropped'
      }.freeze

      # --- Per-impl flaky-test bypasses ------------------------------------
      # Last-resort skip list for tests that flake on one driver impl AND
      # resist a real fix (driver bug confirmed but blocked on upstream,
      # server-side timing outside our control, etc.). Use sparingly —
      # ALWAYS prefer fixing the flake. Every entry here hides a real
      # regression over time, so each one should record WHY a fix isn't
      # viable now and ideally link to a tracking issue.
      #
      # Keyed by Loader.jruby? — the mri-on-jruby flavour loads the MRI
      # driver, so it uses the :mri bucket.
      FLAKY_SKIP_PATTERNS = {
        jruby: {
          # Flaky on the 5.26-enterprise-cluster profile only — looks like
          # cluster-discovery/replication timing rather than a driver bug.
          # On the 4.4-enterprise profile it passes reliably, but StartTest
          # can't gate by profile, so the skip covers both profiles and the
          # baselines drop their 4.4 entries in the same change. Re-enable
          # once the cluster timing is sorted out.
          /\.test_multi_db_various_databases\z/ =>
            'Flaky on 5.26-enterprise-cluster (cluster-discovery timing)'
        }.freeze,
        mri: {
          # Same flake on mri / mri-on-jruby (mri-on-jruby uses :mri bucket).
          /\.test_multi_db_various_databases\z/ =>
            'Flaky on 5.26-enterprise-cluster (cluster-discovery timing)'
        }.freeze
      }.freeze

      def process
        reason = SKIP_PATTERNS.find { |pattern, _| pattern.match?(test_name) }&.last \
              || FLAKY_SKIP_PATTERNS[flaky_impl].find { |pattern, _| pattern.match?(test_name) }&.last
        reason ? skip(reason) : run
      end

      def flaky_impl = Neo4j::Driver::Loader.jruby? ? :jruby : :mri

      def run(_ = nil)
        named_entity('RunTest')
      end

      def skip(reason = 'Skipping passing')
        named_entity('SkipTest', reason: reason)
      end
    end
  end
end
