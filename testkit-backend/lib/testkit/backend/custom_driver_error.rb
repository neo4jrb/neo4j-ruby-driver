module Testkit
  module Backend
    class CustomDriverError < RuntimeError
      def initialize(cause)
        super
      end
    end
  end
end
