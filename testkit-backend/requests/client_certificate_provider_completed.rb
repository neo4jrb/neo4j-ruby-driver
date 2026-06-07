module TestkitBackend
  module Requests
    # Frontend reply to a backend->frontend ClientCertificateProviderRequest,
    # read inline by NewClientCertificateProvider#request_client_certificate
    # (it pulls `.has_update` / `.client_certificate` off this message).
    # Writes no response of its own — cf. AuthTokenManagerGetAuthCompleted.
    class ClientCertificateProviderCompleted < Request
      def process; end
    end
  end
end
