module Neo4j::Driver
  module Internal
    class ImpersonationUtil
      IMPERSONATION_UNSUPPORTED_ERROR_MESSAGE = 'Detected connection that does not support impersonation, please make sure to have all servers running 4.4 version or above and communicating over Bolt version 4.4 or above when using impersonation feature'

      def self.ensure_impersonation_support(connection, impersonated_user)
        if !impersonated_user.nil? && !supports_impersonation?(connection)
          raise Neo4j::Driver::Exceptions::ClientException, IMPERSONATION_UNSUPPORTED_ERROR_MESSAGE
        end

        connection
      end

      private

      def self.supports_impersonation?(connection)
        connection.server_version.greater_than_or_equal(Util::ServerVersion::V4_4_0) &&
        connection.protocol.version.compare_to( Messaging::V44::BoltProtocolV44::VERSION ) >= 0
      end
    end
  end
end
