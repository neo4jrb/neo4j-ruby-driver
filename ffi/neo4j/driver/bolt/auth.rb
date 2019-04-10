# frozen_string_literal: true

require 'neo4j/driver/bolt/value'

module Bolt
  module Auth
    extend Bolt::Library
    attach_function :basic, :BoltAuth_basic, %i[string string string], :pointer, auto_release: true, module: Bolt::Value
    attach_function :none, :BoltAuth_none, [], :pointer, auto_release: true, module: Bolt::Value
  end
end
