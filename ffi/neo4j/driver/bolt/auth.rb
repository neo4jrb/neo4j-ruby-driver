# frozen_string_literal: true

require 'neo4j/driver/bolt/value'

module Bolt
  module Auth
    extend Bolt::Library
    attach_function :basic, :BoltAuth_basic, %i[string string string], :auto_pointer,
                    releaser: Bolt::Value.method(:destroy)
    attach_function :none, :BoltAuth_none, [], :auto_pointer, releaser: Bolt::Value.method(:destroy)
  end
end
