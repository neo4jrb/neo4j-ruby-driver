# frozen_string_literal: true

module Bolt
  module Auth
    extend Bolt::Library
    attach_function :basic, :BoltAuth_basic, %i[string string string], :pointer
    # attach_function :destroy, :BoltAuth_destroy, [:pointer], :void
  end
end
