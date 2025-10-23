module Testkit::Backend::Messages
  module Responses
    class Record < Response
      def data = { values: @object.values.map(&method(:to_testkit)) }
    end
  end
end
