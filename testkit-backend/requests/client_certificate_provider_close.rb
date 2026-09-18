# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Stub; see NewClientCertificateProvider.
    class ClientCertificateProviderClose < Request
      def process
        delete(id)
        named_entity('ClientCertificateProvider', id: id)
      end
    end
  end
end
