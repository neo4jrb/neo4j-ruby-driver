module TestkitBackend
  module Requests
    # Creates a managed client-certificate provider (mutual TLS). The
    # returned manager is stored and later handed to NewDriver via
    # `clientCertificateProviderId`; each time the driver needs a
    # certificate it calls back into `get_client_certificate`, which
    # round-trips to the frontend (blocking) the same way
    # NewAuthTokenManager does. The frontend replies with
    # ClientCertificateProviderCompleted: a fresh certificate when
    # `hasUpdate`, otherwise nil so the driver keeps the current one.
    class NewClientCertificateProvider < Request
      def process
        reference('ClientCertificateProvider')
      end

      def to_object
        manager = nil
        manager = Neo4j::Driver::ClientCertificateManager.new do
          request_client_certificate(manager.object_id)
        end
      end

      private

      def request_client_certificate(provider_id)
        @command_processor.process_response(
          named_entity('ClientCertificateProviderRequest', id: provider_id, client_certificate_provider_id: provider_id))
        completed = @command_processor.process(blocking: true)
        return unless completed.has_update

        cert = completed.client_certificate
        cert_file = java.io.File.new(cert[:certfile])
        key_file = java.io.File.new(cert[:keyfile])
        if cert[:password]
          Neo4j::Driver::ClientCertificates.of(cert_file, key_file, cert[:password])
        else
          Neo4j::Driver::ClientCertificates.of(cert_file, key_file)
        end
      end
    end
  end
end
