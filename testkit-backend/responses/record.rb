# frozen_string_literal: true

module TestkitBackend
  module Responses
    # Renders a driver Record as testkit's Record response (its values serialised).
    class Record < Response
      def data = { values: @object.values.map(&self.class.method(:to_testkit)) }
    end
  end
end
