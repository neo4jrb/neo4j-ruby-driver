# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Tear down a client-certificate-provider handle.
    class ClientCertificateProviderClose < Data.define(:id)
      include Request

      def execute
        registry.delete(id)
        Response::ClientCertificateProvider.new(id: id)
      end
    end
  end
end
