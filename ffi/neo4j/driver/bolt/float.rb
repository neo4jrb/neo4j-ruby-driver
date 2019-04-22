# frozen_string_literal: true

module Bolt
  module Float
    extend Bolt::Library

    attach_function :get, :BoltFloat_get, %i[pointer], :double
  end
end
