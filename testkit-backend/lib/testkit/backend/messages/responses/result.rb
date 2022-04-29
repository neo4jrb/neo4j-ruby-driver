module Testkit::Backend::Messages
  module Responses
    class Result < Response
      def data
        { id: store(@object), keys: @object.keys }
      end
    end
  end
end
