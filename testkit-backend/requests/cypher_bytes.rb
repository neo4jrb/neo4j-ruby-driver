# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Decodes a testkit CypherBytes (space-separated hex pairs) into a binary String.
    class CypherBytes < Request
      def to_object
        value.split.map { |byte| byte.to_i(16) }.pack('C*')
      end
    end
  end
end
