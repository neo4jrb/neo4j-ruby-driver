# frozen_string_literal: true

module Bolt
  module SocketOptions
    extend Bolt::Library

    attach_function :create, :BoltSocketOptions_create, [], :auto_pointer
    attach_function :destroy, :BoltSocketOptions_destroy, [:pointer], :void
    attach_function :get_connect_timeout, :BoltSocketOptions_get_connect_timeout, [:pointer], :int32_t
    attach_function :set_connect_timeout, :BoltSocketOptions_set_connect_timeout, %i[pointer int32_t], :int32_t
    attach_function :get_keep_alive, :BoltSocketOptions_get_keep_alive, [:pointer], :int32_t
    attach_function :set_keep_alive, :BoltSocketOptions_set_keep_alive, %i[pointer int32_t], :int32_t
  end
end
