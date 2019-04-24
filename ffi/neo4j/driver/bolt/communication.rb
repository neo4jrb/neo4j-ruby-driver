# frozen_string_literal: true

module Bolt
  module Communication
    extend Bolt::Library
    attach_function :startup, :BoltCommunication_startup, [], :int
    attach_function :shutdown, :BoltCommunication_shutdown, [], :int
    attach_function :open, :BoltCommunication_open, %i[pointer pointer string], :int
    attach_function :send, :BoltCommunication_send, %i[pointer pointer int string], :int
    attach_function :close, :BoltCommunication_close, %i[pointer string], :int
    attach_function :receive, :BoltCommunication_receive,
                    %i[pointer pointer int int pointer string], :int
    attach_function :local_endpoint, :BoltCommunication_local_endpoint, %i[pointer], :pointer
    attach_function :remote_endpoint, :BoltCommunication_remote_endpoint, %i[pointer], :pointer
    attach_function :remote_endpoint, :BoltCommunication_destroy, %i[pointer], :void
  end
end
