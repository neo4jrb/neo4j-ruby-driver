# frozen_string_literal: true

module Bolt
  module Status
    extend Bolt::Library

    typedef :int32, :bolt_connection_state

    attach_function :create, :BoltStatus_create, [], :auto_pointer
    attach_function :destroy, :BoltStatus_destroy, [:pointer], :void
    attach_function :get_state, :BoltStatus_get_state, [:pointer], :bolt_connection_state
    attach_function :get_error, :BoltStatus_get_error, [:pointer], :int32
    attach_function :get_error_context, :BoltStatus_get_error_context, [:pointer], :string
  end
end
