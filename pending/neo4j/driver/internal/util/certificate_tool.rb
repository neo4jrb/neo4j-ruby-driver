module Neo4j::Driver
  module Internal
    module Util

      # A tool used to save, load certs, etc.
      class CertificateTool
        BEGIN_CERT = "-----BEGIN CERTIFICATE-----"
        END_CERT = "-----END CERTIFICATE-----"

        # Save a certificate to a file in base 64 binary format with BEGIN and END strings
        # @param certStr
        # @param certFile
        # @throws IOException
        class << self
          def save_x509_cert(cert_str, cert_file)
            writer = java.io.BufferedWriter.new(java.io.FileWriter.new(cert_file))

            writer.write(BEGIN_CERT)
            writer.new_line

            writer.write(cert_str)
            writer.new_line

            writer.write(END_CERT)
            writer.new_line
          end

          # Save a certificate to a file. Remove all the content in the file if there is any before.

          # @param cert
          # @param certFile
          # @throws GeneralSecurityException
          # @throws IOException

          # Load the certificates written in X.509 format in a file to a key store.

          # @param certFile
          # @param keyStore
          # @throws GeneralSecurityException
          # @throws IOException
          def load_x509_cert(cert_file, key_store)
            input_stream = java.io.BufferedInputStream.new(java.io.FileInputStream.new(cert_file))

            cert_factory = java.security.cert.CertificateFactory.get_instance('X.509')
            cert_count = 0 #The file might contain multiple certs

            while input_stream.available > 0
              begin
                cert = cert_factory.generate_certificate(input_stream)
                cert_count = cert_count + 1
                # load_x509_cert(cert, 'neo4j.javadriver.trustedcert.', cert_count, key_store)
              rescue java.security.cert.CertificateException => e

                # This happens if there is whitespace at the end of the certificate - we load one cert, and then try and load a
                # second cert, at which point we fail
                return if !e.get_cause.nil? && e.get_cause.get_message == 'Empty input'
                raise java.io.IOException.new("Failed to load certificate from `#{cert_file.get_absolute_path}`: #{cert_count} : #{e.get_message}", e)
              end
            end
          end
        end
      end
    end
  end
end
