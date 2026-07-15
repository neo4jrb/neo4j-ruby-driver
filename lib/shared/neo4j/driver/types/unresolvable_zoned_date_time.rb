# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # A ZonedDateTime the driver received with a zone id its runtime's time
      # zone database can't resolve (e.g. the server sent "Europe/Neo4j").
      #
      # Hydration can't build a real Time, but raising mid-record on the reader
      # thread would break the connection and strand the whole result — so the
      # failure is deferred into this placeholder. Any consumer that tries to
      # interpret the value raises (naming the zone), matching the Java driver,
      # while the record and connection stay intact so an open transaction can
      # still roll back cleanly.
      class UnresolvableZonedDateTime
        attr_reader :zone_name

        def initialize(zone_name)
          @zone_name = zone_name
        end

        # The driver error this value stands in for. Raised by any consumer
        # that tries to use it (the testkit backend on serialize; a public-API
        # caller via #value).
        def error
          Exceptions::ClientException.new(
            "The server returned a ZonedDateTime with a zone id (#{@zone_name.inspect}) " \
            "that this runtime's time zone database does not recognise"
          )
        end

        def value
          raise error
        end
      end
    end
  end
end
