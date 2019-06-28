# frozen_string_literal: true

module Bolt
  module Structure
    extend Bolt::Library

    attach_function :code, :BoltStructure_code, %i[pointer], :int16
    attach_function :value, :BoltStructure_value, %i[pointer int32], :pointer
  end
end
