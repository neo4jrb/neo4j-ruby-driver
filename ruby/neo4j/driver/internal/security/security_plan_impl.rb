module Neo4j::Driver::Internal
  module Security
    class SecurityPlanImpl < Struct.new(:requires_encryption, :ssl_context, :requires_hostname_verification,
                                        :revocation_strategy)
      class << self
        def for_all_certificates(requires_hostname_verification, revocation_strategy)
          ssl_context = javax.net.ssl.SSLContext.get_instance('TLS')
          ssl_context.init(javax.net.ssl.KeyManager[0].new, [TrustAllTrustManager.new].to_java(javax.net.ssl.KeyManager), nil)
          new(true, ssl_context, requires_hostname_verification, revocation_strategy)
        end

        def for_custom_ca_signed_certificate(cert_file, requires_hostname_verification, revocation_strategy)
          ssl_context = config_ssl_context(cert_file, revocation_strategy)
          new(true, ssl_context, requires_hostname_verification, revocation_strategy)
        end

        def for_system_ca_signed_certificate(requires_hostname_verification, revocation_strategy)
          ssl_context = config_ssl_context(nil, revocation_strategy)
          new(true, ssl_context, requires_hostname_verification, revocation_strategy)
        end

        def insecure
          new(false, nil, false, RevocationStrategy::NO_CHECKS)
        end

        private

        def configure_ssl_context(custom_cert_file, revocation_strategy)
          trusted_key_store = java.security.KeyStore.get_instance(java.security.KeyStore.get_default_type)
          trusted_key_store.load(nil, nil)

          if !custom_cert_file.nil?
            Util::CertificateTool.loadX509_cert(custom_cert_file, trusted_key_store)
          else
            load_system_certificates(trusted_key_store)
          end

          pkix_builder_parameters = java.security.cert.PKIXBuilderParameters.new(trusted_key_store, java.security.cert.X509CertSelector.new)
          pkix_builder_parameters.set_revocation_enabled(RevocationStrategy.requires_revocation_checking?(revocation_strategy))

          if RevocationStrategy.requires_revocation_checking?(revocation_strategy)
            java.lang.System.set_property('jdk.tls.client.enableStatusRequestExtension', true)
            if revocation_strategy == RevocationStrategy::VERIFY_IF_PRESENT
              java.security.Security.set_property('ocsp.enable', true)
            end
          end

          ssl_context = javax.net.ssl.SSLContext.get_instance('TLS')

          trust_manager_factory = javax.net.ssl.TrustManager.get_instance(javax.net.ssl.TrustManagerFactory.get_default_algorithm)
          trust_manager_factory.init(javax.net.ssl.CertPathTrustManagerParameters.new(pkix_builder_parameters))
          ssl_context.init(javax.net.ssl.KeyManager[0].new, trust_manager_factory.get_trust_managers, nil)
          ssl_context
        end

        def load_system_certificates(trusted_key_store)
          temp_factory = javax.net.ssl.TrustManagerFactory.get_instance(javax.net.ssl.TrustManagerFactory.get_default_algorithm)
          temp_factory.init(nil)

          x509_trust_manager = nil
          temp_factory.get_trust_managers.each do |trust_manager|
            if trust_manager.is_a?(javax.net.ssl.X509TrustManager)
              x509_trust_manager = javax.net.ssl.X509TrustManager.java_class.cast(trust_manager)
              break
            end
          end

          if x509_trust_manager.nil?
            raise Neo4j::Driver::Exceptions::CertificateException, 'No system certificates found'
          else
            Util::CertificateTool.load_x509_cert(x509_trust_manager.get_accepted_issuer, trusted_key_store)
          end
        end
      end

      class TrustAllTrustManager
        def check_client_trusted(chain, auth_type)
          raise Neo4j::Driver::Exceptions::CertificateException, 'All client connections to this client are forbidden.'
        end

        def check_server_trusted(chain, auth_type)
        end

        def get_accepted_issuers
          java.security.cert.X509Certificate[0].new
        end
      end

      private_constant :TrustAllTrustManager
    end
  end
end
