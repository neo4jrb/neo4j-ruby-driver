# frozen_string_literal: true

module Bolt
  module Address
    extend Bolt::Library
    attach_function :create, :BoltAddress_create, %i[string string], :auto_pointer
    attach_function :host, :BoltAddress_host, %i[pointer], :string
    attach_function :port, :BoltAddress_port, %i[pointer], :string
    attach_function :destroy, :BoltAddress_destroy, %i[pointer], :void
  end
end
