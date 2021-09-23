module Testkit::Backend::Messages
  module Responses
    class DriverError < Response
      def self.from(exception)
        { id: exception.object_id, errorType: exception.class.name, msg: exception.message, code: exception.code }
      end
    end
  end
end
