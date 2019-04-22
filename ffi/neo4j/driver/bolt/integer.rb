# frozen_string_literal: true

module Bolt
  module Integer
    extend Bolt::Library

    attach_function :get, :BoltInteger_get, %i[pointer], :int64_t
  end
end
