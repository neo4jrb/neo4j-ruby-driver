module TestkitBackend
  module Responses
    class Result < Response
      def data
        { id: store(@object), keys: @object.keys }
      end
    end
  end
end
