module Testkit::Backend::Messages
  module Requests
    class StartTest < Request
      SKIPPED_TESTS = {
        'neo4j.test_direct_driver.TestDirectDriver.test_custom_resolver':
          'Does not call resolver for direct connections',
        'stub.iteration.test_iteration_tx_run.TestIterationTxRun.test_nested':
          'completely pulls the first query before running the second',
      }.transform_keys(&:to_s)

      def process
        if SKIPPED_TESTS.key?(testName)
          named_entity("SkipTest", reason: SKIPPED_TESTS[testName])
        else
          named_entity('RunTest')
        end
      end
    end
  end
end
