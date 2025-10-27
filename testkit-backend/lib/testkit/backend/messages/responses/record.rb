module Testkit::Backend::Messages
  module Responses
    class Record < Response
      def data = { values: @object.values.map(&self.class.method(:to_testkit)) }
    end
  end
end
