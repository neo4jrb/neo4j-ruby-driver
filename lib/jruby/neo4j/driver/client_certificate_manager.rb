# frozen_string_literal: true

module Neo4j
  module Driver
    # JRuby flavour of a client-certificate manager: supply a block that
    # returns the current client certificate — or `nil` when nothing has
    # changed since the last call — and pass an instance to
    # `GraphDatabase.driver` via `client_certificate_manager:`. The driver
    # calls back whenever it needs a (possibly rotated) certificate for the
    # mutual-TLS handshake.
    #
    # The class `include`s org.neo4j.driver.ClientCertificateManager in its
    # body because JRuby only builds the Java interface proxy at
    # class-definition time; a retroactive include wouldn't produce a usable
    # impl, and subclasses inherit the interface. The Java SPI asks for a
    # CompletionStage<ClientCertificate>, so the synchronous block result is
    # wrapped in a pre-completed future (a `nil` result is a valid "no
    # change" answer).
    class ClientCertificateManager
      include Java::OrgNeo4jDriver::ClientCertificateManager

      def initialize(&get_client_certificate)
        @get_client_certificate = get_client_certificate
      end

      def get_client_certificate
        java.util.concurrent.CompletableFuture.completed_future(@get_client_certificate.call)
      end
    end
  end
end
