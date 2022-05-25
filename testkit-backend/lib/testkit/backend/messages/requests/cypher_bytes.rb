module Testkit::Backend::Messages
  module Requests
    class CypherBytes < Request
      def to_object
        value.split.map { |byte| byte.to_i(16) }.pack('C*')
      end
    end
  end
end
