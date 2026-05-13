module TestkitBackend
  module Requests
    # Stub: the Ruby driver doesn't advertise Feature:API:SSLClientCertificate.
    class NewClientCertificateProvider < Request
      def process
        reference('ClientCertificateProvider')
      end

      def to_object
        Object.new
      end
    end
  end
end
