# frozen_string_literal: true

module Bolt
  module AddressResolver
    extend Bolt::Library

    callback :address_resolver_func, [:pointer, :pointer, :pointer], :pointer

    attach_function :create, :BoltAddressResolver_create, %i[pointer address_resolver_func],
                    :pointer
    attach_function :destroy, :BoltAddressResolver_destroy, %i[pointer], :void
  end
end