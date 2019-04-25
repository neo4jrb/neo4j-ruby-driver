# frozen_string_literal: true

module Bolt
  module Config
    extend Bolt::Library

    attach_function :create, :BoltConfig_create, [], :auto_pointer
    attach_function :destroy, :BoltConfig_destroy, [:pointer], :void
    attach_function :set_user_agent, :BoltConfig_set_user_agent, %i[pointer string], :int32_t
  end
end
