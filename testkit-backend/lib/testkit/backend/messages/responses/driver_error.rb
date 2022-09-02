module Testkit::Backend::Messages
  module Responses
    class DriverError < Response
      def data
        p 111111111
        p @object.class.name
        p 3333333333333333333333333333333
        p @object.message
        p 4444444444444444444444444444444
        p @object.code
        p 4444444444444444444444444444444
        p @object.methods
        p 111111111
        { id: store(@object), errorType: @object.class.name, msg: @object.message, code: @object.try(:code) }.compact
      end
    end
  end
end
