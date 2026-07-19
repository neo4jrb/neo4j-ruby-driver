# frozen_string_literal: true

module Neo4j
  module Driver
    # Factory for ClientCertificateManager, mirroring
    # org.neo4j.driver.ClientCertificateManagers.
    module ClientCertificateManagers
      # A manager that presents the given (static) client certificate on every
      # request — the non-rotating case.
      def self.rotating(client_certificate)
        ClientCertificateManager.new { client_certificate }
      end
    end
  end
end
