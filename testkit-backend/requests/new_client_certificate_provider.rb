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
        completed = @command_processor.callback(
          named_entity('ClientCertificateProviderRequest', id: provider_id, client_certificate_provider_id: provider_id))
        return unless completed.has_update

        # The wire shape nests the cert fields under `data`.
        Request.client_certificate_from(completed.client_certificate[:data])
      end
    end
  end
end
