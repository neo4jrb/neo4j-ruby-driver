# frozen_string_literal: true

module Bolt
  module Boolean
    extend Bolt::Library

    attach_function :get, :BoltBoolean_get, %i[pointer], :char
  end
end
