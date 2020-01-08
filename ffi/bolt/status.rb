# frozen_string_literal: true

module Bolt
  module Status
    extend Bolt::Library
    # Not connected
    BOLT_CONNECTION_STATE_DISCONNECTED = 0
    # Connected but not authenticated
    BOLT_CONNECTION_STATE_CONNECTED = 1
    # Connected and authenticated
    BOLT_CONNECTION_STATE_READY = 2
    # Recoverable failure
    BOLT_CONNECTION_STATE_FAILED = 3
    # Unrecoverable failure
    BOLT_CONNECTION_STATE_DEFUNCT = 4

    typedef :int32, :bolt_connection_state

    attach_function :create, :BoltStatus_create, [], :auto_pointer
    attach_function :destroy, :BoltStatus_destroy, [:pointer], :void
    attach_function :get_state, :BoltStatus_get_state, [:pointer], :bolt_connection_state
    attach_function :get_error, :BoltStatus_get_error, [:pointer], :int32
    attach_function :get_error_context, :BoltStatus_get_error_context, [:pointer], :string
  end
end
