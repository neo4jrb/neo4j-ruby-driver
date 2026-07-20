# frozen_string_literal: true

module Neo4j
  module Driver
    # Supplies the current client certificate for mutual TLS
    # (Feature:API:SSLClientCertificate). Wrap a block that returns a
    # ClientCertificate — or nil when nothing changed since the last call, in
    # which case the previously supplied certificate is kept. Pass an instance
    # to GraphDatabase.driver via `client_certificate_manager:`; the driver
    # consults it whenever a connection needs a (possibly rotated) certificate.
    #
    # The MRI counterpart of the Java driver's org.neo4j.driver
    # .ClientCertificateManager (whose get returns null for "no change"); the
    # last non-nil certificate is retained here so a fresh per-connection TLS
    # context always presents the current one.
    class ClientCertificateManager
      def initialize(&get_client_certificate)
        @get_client_certificate = get_client_certificate
        @current = nil
        @mutex = Mutex.new
      end

      # The current client certificate. Polls the block; a non-nil result
      # rotates the retained certificate, a nil result keeps it. Connections
      # are acquired concurrently, so the poll-and-update is serialized: it
      # keeps @current consistent and stops a blocking provider (the testkit
      # callback round-trips to the frontend) from being entered concurrently.
      def get_client_certificate
        @mutex.synchronize do
          certificate = @get_client_certificate.call
          @current = certificate if certificate
          @current
        end
      end
    end
  end
end
