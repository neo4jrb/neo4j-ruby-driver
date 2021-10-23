module Testkit::Backend::Messages
  module Requests
    class CypherFloat < Request
      def to_object
        case value
        when "NaN"
          Float::NAN
        when "-Infinity"
          -Float::INFINITY
        when "+Infinity"
          Float::INFINITY
        else
          value.to_f
        end
      end
    end
  end
end
