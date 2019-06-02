# frozen_string_literal: true

module Bolt
  module List
    extend Bolt::Library

    attach_function :resize, :BoltList_resize, %i[pointer int32], :void
    attach_function :value, :BoltList_value, %i[pointer int32], :pointer
  end
end
