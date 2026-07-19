# frozen_string_literal: true

module Neo4j
  module Driver
    # Factory for ClientCertificate, mirroring org.neo4j.driver.ClientCertificates.
    # Accepts path strings (or anything with #to_s, e.g. a Pathname) for the
    # certificate and private-key PEM files, plus the key's optional password.
    module ClientCertificates
      def self.of(certfile, keyfile, password = nil)
        ClientCertificate.new(certfile.to_s, keyfile.to_s, password)
      end
    end
  end
end
