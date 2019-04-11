# frozen_string_literal: true

module Bolt
  module Address
    extend Bolt::Library
    attach_function :create, :BoltAddress_create, %i[string string], :auto_pointer
    attach_function :destroy, :BoltAddress_destroy, [:pointer], :void
  end
end
