# frozen_string_literal: true

module Neo4j
  module Driver
    # A client certificate for mutual TLS (Feature:API:SSLClientCertificate):
    # the certificate PEM file, its private-key PEM file, and the key's
    # optional password. Built via ClientCertificates.of and served by a
    # ClientCertificateManager. Mirrors org.neo4j.driver.ClientCertificate.
    class ClientCertificate
      attr_reader :certfile, :keyfile, :password

      def initialize(certfile, keyfile, password = nil)
        @certfile = certfile
        @keyfile = keyfile
        @password = password
      end
    end
  end
end
