# frozen_string_literal: true

module Bolt
  module AddressResolver
    extend Bolt::Library

    callback :address_resolver_func, %i[pointer pointer pointer], :void

    attach_function :create, :BoltAddressResolver_create, %i[pointer address_resolver_func], :auto_pointer
    attach_function :destroy, :BoltLog_destroy, %i[pointer], :void
  end
end
