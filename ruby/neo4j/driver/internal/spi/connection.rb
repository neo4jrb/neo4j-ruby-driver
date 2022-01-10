module Neo4j::Driver
  module Internal
    module Spi
      module Connection
        def mode
          raise java.lang.UnsupportedOperationException, "#{self.class} does not support access mode."
        end

        def database_name
          raise java.lang.UnsupportedOperationException, "#{self.class} does not support database name."
        end

        def impersonated_user
          raise java.lang.UnsupportedOperationException, "#{self.class} does not support impersonated user."
        end
      end
    end
  end
end
