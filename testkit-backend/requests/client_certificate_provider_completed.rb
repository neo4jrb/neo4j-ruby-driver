module TestkitBackend
  module Requests
    # Frontend response to a backend->frontend ClientCertificate request.
    # We never emit one. Stub for parity.
    class ClientCertificateProviderCompleted < Request
      def process
        named_entity('BackendError',
                     msg: 'ClientCertificateProvider callbacks are not implemented (driver does not advertise Feature:API:SSLClientCertificate)')
      end
    end
  end
end
