# frozen_string_literal: true

module Bolt
  module Connector
    extend Bolt::Library

    BoltAccessMode = enum(
      :bolt_access_mode_write,
      :bolt_access_mode_read
    )

    attach_function :create, :BoltConnector_create, %i[pointer pointer pointer], :pointer
    attach_function :destroy, :BoltConnector_destroy, [:pointer], :void
    attach_function :acquire, :BoltConnector_acquire, [:pointer, BoltAccessMode, :pointer], :pointer
    attach_function :release, :BoltConnector_release, %i[pointer pointer], :void
  end
end
