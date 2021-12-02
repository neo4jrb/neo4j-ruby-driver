module Neo4j::Driver::Internal
  module Security
    class SecurityPlanImpl < Struct.new(:requires_encryption, :ssl_context, :requires_hostname_verification,
                                        :revocation_strategy)
      
      def for_all_certificates(requires_hostname_verification, revocation_strategy)
        ssl_context = javax.net.ssl.SSLContext.getInstance("TLS")
        ssl_context.init(new javax.net.ssl.KeyManager[0], new javax.net.ssl.TrustManage[]{TrustAllTrustManager.new}, nil)
        SecurityPlanImpl.new(true, ssl_context, requires_hostname_verification, revocation_strategy)
      end

      def for_custom_ca_signed_certificate(cert_file, requires_hostname_verification, revocation_strategy)
        ssl_context = config_ssl_context(cert_file, revocation_strategy)
        SecurityPlanImpl.new(true, ssl_context, requires_hostname_verification, revocation_strategy)
      end

      def for_system_casigned_certificate(requires_hostname_verification, revocation_strategy)
        ssl_context = config_ssl_context(nil, revocation_strategy)
        SecurityPlanImpl.new(true, ssl_context, requires_hostname_verification, revocation_strategy)
      end

      class << self
        def insecure
          new(false, nil, false, RevocationStrategy::NO_CHECKS)
        end
      end

      private

      def initialize(requires_encryption, ssl_context, requires_hostname_verification, revocation_strategy)
        REQUIRE_ENCRYPTION = requires_encryption
        SSL_CONTEXT = ssl_context
        REQUIRES_HOSTNAME_VERIFICATION = requires_hostname_verification
        REVOCATIONSTRATEGY = revocation_strategy
      end

      def config_ssl_context(custom_cert_file, revocation_strategy)
        trusted_key_store = java.security.KeyStore.getInstance(java.security.KeyStore.getDefaultType())
        trusted_key_store.load(nil, nil)

        if !custom_cert_file.nil?
          org.neo4j.driver.internal.util.CertificateTool.loadX509Cert(custom_cert_file, trusted_key_store)
        else
          load_system_certificates(trusted_key_store)
        end

        pkix_builder_parameters = new java.security.cert.PKIXBuilderParameters(trusted_key_store, new java.security.cert.X509CertSelector())
        pkix_builder_parameters.setRevocationEnabled(org.neo4j.driver.internal.RevocationStrategy.requiresRevocationChecking(revocation_strategy))

        if org.neo4j.driver.internal.RevocationStrategy.requiresRevocationChecking(revocation_strategy)
          System.set_property("jdk.tls.client.enableStatusRequestExtension", true)
          if revocation_strategy.eql?(org.neo4j.driver.internal.RevocationStrategy.VERIFY_IF_PRESENT)
            Security.set_property("ocsp.enable", true)
          end
        end

        ssl_context = javax.net.ssl.SSLContext.getInstance("TLS")

        trust_manager_factory = javax.net.ssl.TrustManager.getInstance(javax.net.ssl.TrustManagerFactory.getDefaultAlgorithm())
        trust_manager_factory.init(new javax.net.ssl.CertPathTrustManagerParameters(pkix_builder_parameters))
        ssl_context.init(new javax.net.ssl.KeyManager[0], trust_manager_factory.getTrustManagers(), nil)
        ssl_context
      end

      def load_system_certificates(trusted_key_store)
        temp_factory = javax.net.ssl.TrustManagerFactory.getInstance(javax.net.ssl.TrustManagerFactory.getDefaultAlgorithm())
        temp_factory.init((java.security.KeyStore) nil)

        x509_trust_manager = nil
        temp_factory.get_trust_managers.each do |trust_manager|
          if trust_manager.kind_of?(javax.net.ssl.X509TrustManager)
            x509_trust_manager = (javax.net.ssl.X509TrustManager) trust_manager
            break
          end
        end

        if x509_trust_manager.nil?
          raise Neo4j::Driver::Exceptions::CertificateException, "No system certificates found"
        else
          org.neo4j.driver.internal.util.CertificateTool.loadX509Cert(x509_trust_manager.getAcceptedIssuer(), trusted_key_store)
        end
      end

      class TrustAllTrustManager < javax.net.ssl.X509TrustManager
        def check_client_trusted(chain, auth_type)
          raise Neo4j::Driver::Exceptions::CertificateException, "All client connections to this client are forbidden."
        end

        def check_server_trusted(chain, auth_type)
          
        end

        def get_accepted_issuers
          java.security.cert.X509Certificate[0]
        end
      end
    end
  end
end
