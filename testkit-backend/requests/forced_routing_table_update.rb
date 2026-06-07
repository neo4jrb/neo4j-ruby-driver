module TestkitBackend
  module Requests
    # testkit only sends this when the impl advertises
    # Feature.BACKEND_RT_FORCE_UPDATE (see GetFeatures) — MRI today;
    # the driver decides how to force the refresh.
    class ForcedRoutingTableUpdate < Request
      def process
        fetch(driver_id).routing_table_refresh(database, bookmarks)
        named_entity('Driver', id: driver_id)
      end
    end
  end
end
