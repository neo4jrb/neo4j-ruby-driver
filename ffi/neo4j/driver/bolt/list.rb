# frozen_string_literal: true

module Bolt
  module List
    extend Bolt::Library

    attach_function :value, :BoltList_value, %i[pointer int32_t], :pointer
  end
end
