module TestkitBackend
  module Requests
    # Stub: the Ruby driver doesn't advertise Feature:Auth:Managed, so
    # testkit shouldn't drive these. We still register the request so
    # an out-of-order call surfaces as a clean BackendError rather
    # than "uninitialized constant Requests::NewAuthTokenManager".
    class NewAuthTokenManager < Request
      def process
        reference('AuthTokenManager')
      end

      def to_object
        Object.new
      end
    end
  end
end
