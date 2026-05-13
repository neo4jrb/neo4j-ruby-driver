module TestkitBackend
  module Requests
    # Mirrors Java testkit-backend StartSubTest.java. For tests that
    # parametrise over time-zone ids or datetime fields the backend may
    # skip individual subtests whose params can't be expressed in the
    # local TZ database / can't round-trip through this VM's datetime
    # type.
    #
    # testkit invokes us only for tests whose StartTest response was
    # RunSubTests. We currently respond RunTest at StartTest, so this
    # handler is exercised only when testkit explicitly asks per-
    # subtest (rare), but it's wired anyway to mirror the Java backend.
    class StartSubTest < Request
      SKIP_CHECKERS = {
        /\Aneo4j\.datatypes\.test_temporal_types\.TestDataTypes\.test_should_echo_all_timezone_ids\z/ =>
          :check_date_time_supported,
        /\Aneo4j\.datatypes\.test_temporal_types\.TestDataTypes\.test_date_time_cypher_created_tz_id\z/ =>
          :check_tz_id_supported
      }.freeze

      def process
        SKIP_CHECKERS.each do |pattern, checker|
          next unless pattern.match?(test_name)

          reason = send(checker, subtest_arguments || {})
          return reason ? skip(reason) : run
        end
        run
      end

      private

      # tzinfo (already a driver runtime dep) is the authoritative source
      # for whether an IANA zone id is known. The check matches Java's
      # ZoneId.getAvailableZoneIds().contains(tzId).
      def check_tz_id_supported(params)
        tz_id = params['tz_id']
        TZInfo::Timezone.get(tz_id) && nil
      rescue TZInfo::InvalidTimezoneIdentifier
        "Timezone not supported: #{tz_id}"
      end

      # Mirror Java: try to construct a zoned datetime from the supplied
      # params and verify the explicit utc_offset matches what tzinfo
      # would derive for that instant. Skip if either step fails.
      def check_date_time_supported(params)
        data = params.dig('dt', 'data') or raise "param 'dt' expected to contain 'data'"
        tz = TZInfo::Timezone.get(data['timezone_id'])
        local = ::Time.new(data['year'], data['month'], data['day'],
                           data['hour'], data['minute'],
                           data['second'] + data['nanosecond'] / 1e9, 0)
        derived_offset = tz.period_for_local(local, true).utc_total_offset
        return nil if derived_offset == data['utc_offset_s']

        "DateTime not supported: Unmatched UTC offset. TestKit expected " \
        "#{data['utc_offset_s']}, local zone db yielded #{derived_offset}"
      rescue TZInfo::InvalidTimezoneIdentifier, TZInfo::AmbiguousTime, TZInfo::PeriodNotFound, ArgumentError => e
        "DateTime not supported: #{e.message}"
      end

      def run
        named_entity('RunTest')
      end

      def skip(reason)
        named_entity('SkipTest', reason: reason)
      end
    end
  end
end
