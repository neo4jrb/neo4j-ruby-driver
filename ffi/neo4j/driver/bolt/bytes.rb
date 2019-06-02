# frozen_string_literal: true

module Bolt
  module Bytes
    extend Bolt::Library

    attach_function :get, :BoltBytes_get, %i[pointer int32], :char
    attach_function :get_all, :BoltBytes_get_all, %i[pointer], :pointer
  end
end
