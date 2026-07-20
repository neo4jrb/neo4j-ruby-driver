# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Resolves the driver's URI scheme + user options into an
      # OpenSSL::SSL::SSLContext, or nil for plaintext. Mirrors Java's
      # TrustStrategy modes:
      #
      #   :system_certificates  — verify cert chain against system roots
      #                            + verify hostname. Default for +s schemes.
      #   :all_certificates     — encrypted but skip both checks. Default
      #                            for +ssc schemes. Useful for self-signed
      #                            dev servers; not for production.
      #   :custom_certificates  — verify against an explicit CA bundle.
      #
      # Hostname verification rides along with peer verification — turning
      # peer verification off (:all_certificates) implicitly turns off
      # hostname check too, which is why +ssc exists.
      class TlsConfig
        # +s / +ssc are scheme-level encryption opt-in (mirrors
        # Driver::ENCRYPTED_SCHEMES). +ssc additionally implies
        # trust-all — the whole point of the "self-signed" suffix.
        ENCRYPTED_SCHEMES = Driver::ENCRYPTED_SCHEMES
        TRUST_ALL_SCHEMES = %w[bolt+ssc neo4j+ssc].freeze

        def initialize(uri:, options:)
          @uri = uri
          @options = options
        end

        # nil ⇒ plaintext socket; SSLContext ⇒ wrap.
        def ssl_context
          return nil unless encrypted?

          ctx = OpenSSL::SSL::SSLContext.new
          ctx.min_version = OpenSSL::SSL::TLS1_2_VERSION
          apply_trust(ctx)
          apply_client_certificate(ctx)
          ctx
        end

        def encrypted?
          ENCRYPTED_SCHEMES.include?(@uri.scheme) || @options[:encryption] == true
        end

        # Whether the SSLSocket should verify the server hostname after
        # the TLS handshake. False for the trust-all path; true otherwise.
        def verify_hostname?
          encrypted? && resolved_strategy != :all_certificates
        end

        private

        # Mutual TLS (Feature:API:SSLClientCertificate): present the client
        # certificate the manager currently holds. Polled per connection so a
        # rotated certificate takes effect on the next connect; nil manager or
        # nil certificate leaves the context client-cert-free.
        def apply_client_certificate(ctx)
          certificate = @options[:client_certificate_manager]&.get_client_certificate
          return unless certificate

          ctx.cert = OpenSSL::X509::Certificate.new(File.read(certificate.certfile))
          # PKey.read handles both encrypted (password used) and unencrypted
          # (password ignored) PEM keys. Pass "" rather than nil for a missing
          # password so an encrypted key raises PKeyError instead of blocking
          # the thread on OpenSSL's interactive stdin passphrase prompt.
          ctx.key = OpenSSL::PKey.read(File.read(certificate.keyfile), certificate.password || '')
        end

        def apply_trust(ctx)
          case resolved_strategy
          when :all_certificates
            ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
          when :custom_certificates
            ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
            ctx.cert_store = custom_cert_store
          else # :system_certificates
            ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
            ctx.cert_store = OpenSSL::X509::Store.new.tap(&:set_default_paths)
          end
        end

        # Custom-trust mode without any `cert_files` paths would produce
        # a VERIFY_PEER context with an empty store — every connection
        # would fail with an opaque OpenSSL error. Catch this at config
        # time with a clear message instead.
        def custom_cert_store
          paths = cert_files
          if paths.empty?
            raise ArgumentError,
                  'trust_strategy :trust_custom_certificates requires at least one path in :cert_files'
          end

          paths.each_with_object(OpenSSL::X509::Store.new) do |path, store|
            store.add_file(path)
          end
        end

        # Resolves trust-strategy option → internal symbol. Falls back
        # to the URI-implied default (+ssc → all-certs, anything else
        # → system-certs) when no explicit option was given.
        def resolved_strategy
          return uri_default unless explicit_strategy

          case explicit_strategy
          when :trust_system_certificates then :system_certificates
          when :trust_all_certificates then :all_certificates
          when :trust_custom_certificates then :custom_certificates
          else
            raise ArgumentError, "Unknown trust_strategy: #{explicit_strategy.inspect}"
          end
        end

        def uri_default
          TRUST_ALL_SCHEMES.include?(@uri.scheme) ? :all_certificates : :system_certificates
        end

        def explicit_strategy
          @options.dig(:trust_strategy, :strategy)
        end

        def cert_files
          Array(@options.dig(:trust_strategy, :cert_files))
        end
      end
    end
  end
end
