# frozen_string_literal: true

module Bolt
  module String
    extend Bolt::Library

    attach_function :get, :BoltString_get, [:pointer], :pointer
  end
end
