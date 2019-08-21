# frozen_string_literal: true

module Neo4j
  module Driver
    class Statement
      attr_reader :text, :parameters

      def initialize(text, parameters = nil)
        @text = text
        @parameters = parameters || {}
      end
    end
  end
end
