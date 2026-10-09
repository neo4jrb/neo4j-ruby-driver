# frozen_string_literal: true

module TestkitBackend
  module Responses
    # Renders a driver Result as testkit's Result response: caches it and
    # returns its id and column keys.
    class Result < Response
      def data
        { id: store(@object), keys: @object.keys }
      end
    end
  end
end
