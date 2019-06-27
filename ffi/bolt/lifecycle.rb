# frozen_string_literal: true

module Bolt
  module Lifecycle
    extend Bolt::Library
    attach_function :startup, :Bolt_startup, [], :void
    attach_function :shutdown, :Bolt_shutdown, [], :void
  end
end
