module Testkit::Backend::Messages
  module Responses
    class DriverError < Response
      def data
        { id: store(@object), errorType: @object.class.name, msg: @object.message, code: @object.try(:code) }.compact
      end
    end
  end
end
