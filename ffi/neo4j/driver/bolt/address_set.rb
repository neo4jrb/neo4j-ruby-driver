# frozen_string_literal: true

module Bolt
  module AddressSet
    extend Bolt::Library

    attach_function :add, :BoltAddressSet_add, %i[pointer pointer], :int32_t
  end
end
