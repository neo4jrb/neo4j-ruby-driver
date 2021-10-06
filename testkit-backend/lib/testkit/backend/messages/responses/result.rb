module Testkit::Backend::Messages
  module Responses
    class Result < Response
      def data
        { id: @object }
      end
    end
  end
end
