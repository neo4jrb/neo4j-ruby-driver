module Neo4j::Driver::Internal
  module Security
    class SecurityPlanImpl < Struct.new(:requires_encryption?, :ssl_context, :requires_hostname_verification?,
                                        :revocation_strategy)
      class << self
        def for_all_certificates(requires_hostname_verification, revocation_strategy)
          new(true, all_context(requires_hostname_verification), requires_hostname_verification, revocation_strategy)
        end

        def for_custom_ca_signed_certificates(cert_files, requires_hostname_verification, revocation_strategy)
          new(true, custom_ca_signed_context(cert_files, requires_hostname_verification),
              requires_hostname_verification, revocation_strategy)
        end

        def for_system_ca_signed_certificates(requires_hostname_verification, revocation_strategy)
          new(true, ca_signed_context(requires_hostname_verification), requires_hostname_verification,
              revocation_strategy)
        end

        def insecure
          new(false, nil, false, RevocationStrategy::NO_CHECKS)
        end

        private

        def all_context(requires_hostname_verification)
          ssl_context(verify_mode: OpenSSL::SSL::VERIFY_NONE, verify_hostname: requires_hostname_verification)
        end

        def ca_signed_context(requires_hostname_verification)
          ssl_context(verify_hostname: requires_hostname_verification)
        end

        def custom_ca_signed_context(cert_files, requires_hostname_verification)
          ssl_context(
            cert_store: OpenSSL::X509::Store.new.tap do |store|
              cert_files.each(&store.method(:add_file))
            end,
            verify_hostname: requires_hostname_verification)
        end

        def ssl_context(**params)
          OpenSSL::SSL::SSLContext.new.tap { |context| context.set_params(params) }
        end
      end
    end
  end
end
