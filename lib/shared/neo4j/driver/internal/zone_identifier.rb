# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # The IANA zone identifier for a TimeWithZone-like value's zone, for the
      # Bolt DateTimeZoneId structure. Matches the Java driver, which sends
      # ZonedDateTime#getZone#getId verbatim: a zone whose own name is already a
      # valid IANA id is kept as-is — so "UTC" stays "UTC" rather than TZInfo's
      # canonical "Etc/UTC" — while an ActiveSupport::TimeZone built from a Rails
      # display name ("Mountain Time (US & Canada)"), which is not a valid id,
      # falls back to its tzinfo identifier ("America/Denver"). Returns nil when
      # the zone exposes no usable identifier (e.g. an offset-only zone), so the
      # caller can fall back to the offset form.
      module ZoneIdentifier
        module_function

        def call(zone)
          name = zone.name if zone.respond_to?(:name)
          return name if name && valid?(name)

          zone.tzinfo.identifier if zone.respond_to?(:tzinfo)
        end

        def valid?(name)
          TZInfo::Timezone.get(name)
          true
        rescue TZInfo::InvalidTimezoneIdentifier
          false
        end
      end
    end
  end
end
