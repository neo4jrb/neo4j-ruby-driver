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
        ENCRYPTED_SCHEMES = %w[bolt+s bolt+ssc neo4j+s neo4j+ssc].freeze
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

        def apply_trust(ctx)
          case resolved_strategy
          when :all_certificates
            ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
          when :custom_certificates
            ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
            store = OpenSSL::X509::Store.new
            cert_files.each { |path| store.add_file(path) }
            ctx.cert_store = store
          else # :system_certificates
            ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
            ctx.cert_store = OpenSSL::X509::Store.new.tap(&:set_default_paths)
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
