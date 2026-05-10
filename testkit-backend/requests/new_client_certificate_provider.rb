# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Creates a client-certificate provider. Used in mutual-TLS
    # configurations: the driver calls back to the provider periodically
    # to fetch a fresh cert. Stores a placeholder; no real provider
    # callback yet.
    #
    # DRIVER GAP: needs ClientCertificateProvider support in
    # Neo4j::Driver. Required pieces:
    #   - Driver accepts :client_certificate_provider option
    #   - TLS connection setup queries the provider for cert/key/password
    #     on each new socket, with the option to indicate "hasUpdate"
    #     (provider tells us whether material has rotated)
    #   - The Ruby Proc round-trips through the testkit channel
    #     (Response::ClientCertificateProviderRequest →
    #      Request::ClientCertificateProviderCompleted)
    class NewClientCertificateProvider < Data.define
      include Request

      def execute
        placeholder = { type: :client_certificate_provider }
        Response::ClientCertificateProvider.new(id: registry.store(placeholder, prefix: 'certprov'))
      end
    end
  end
end
