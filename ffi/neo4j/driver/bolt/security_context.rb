# frozen_string_literal: true

module Bolt
  module SecurityContext
    extend Bolt::Library

    attach_function :startup, :BoltSecurityContext_startup, [], :int
    attach_function :shutdown, :BoltSecurityContext_shutdown, [], :int
    attach_function :create, :BoltSecurityContext_create, %i[pointer string pointer string], :int
    attach_function :destroy, :BoltSecurityContext_destroy, %i[pointer], :void
  end
end
