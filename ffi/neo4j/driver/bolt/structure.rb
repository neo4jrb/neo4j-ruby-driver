# frozen_string_literal: true

module Bolt
  module Structure
    extend Bolt::Library

    attach_function :code, :BoltStructure_code, %i[pointer], :int16_t
    attach_function :value, :BoltStructure_value, %i[pointer int32_t], :pointer
  end
end
